#!/usr/bin/env python

import qualysapi
from lxml import objectify
from lxml.builder import E

import sys
import os
import datetime
import time
import argparse
from argparse import RawTextHelpFormatter
import logging


# logging
if os.getenv('LOG_LEVEL') is None:
    os.environ['LOG_LEVEL'] = 'INFO'

logger = logging.getLogger()
handler = logging.StreamHandler()
formatter = logging.Formatter('%(levelname)-8s %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(logging.os.environ['LOG_LEVEL'])


def update_scan_url(qgc, current_time, args):
    ''' Update WAS scan Name and IP/URL '''

    call = '/update/was/webapp' + '/' + args.webapp_id
    ServiceRequest_xml_header = '''
    <ServiceRequest>
            <data>
              <WebApp>
    '''
    ServiceRequest_xml_footer = '''
              </WebApp>
            </data>
    </ServiceRequest>
    '''
    web_name_tag = '<name>' + args.web_name + ' - ' + args.scan_type_name + ' WAS Scan Launch From API - ' + current_time + '</name>' + '\n'
    web_url_tag = '<url>' + args.web_url + '</url>'
    parameters = ServiceRequest_xml_header + web_name_tag + '\n' + web_url_tag + ServiceRequest_xml_footer

    logger.info('id: %s', parameters)

    xml_output = qgc.request(call, parameters)
    logger.debug('Updated scan_url:  %s', xml_output)
    root = objectify.fromstring(xml_output.encode('utf-8'))

    # Need to check update results
    if root.responseCode != 'SUCCESS':
        logger.error('Error Found: %s', root.responseErrorDetails.errorMessage.text)
    else:
        logger.info('Successfully updated webapp: %s', root.data.WebApp.id.text)
        return root.data.WebApp.id.text

def scan_report(qgc, current_time, args, scan_id):
    call = '/launch/was/wasscan'

    # The scan typically takes less than 10 minutes.
    # One hour is more than sufficient.
    # Don't wait too long as scan might get stuck at various stages
    ServiceRequest_xml_header = '''
    <ServiceRequest>
            <data>
              <WasScan>
    '''
    ServiceRequest_xml_footer = '''
                <cancelAfterNHours>1</cancelAfterNHours>
              </WasScan>
            </data>
    </ServiceRequest>
    '''
    web_scan_name = '<name>' + args.web_name + ' - ' + args.scan_type_name + ' WAS Scan Launch From API - ' + current_time + '</name>' + '\n'
    scan_type = '<type>' + args.scan_type_name + '</type>'
    scan_id_content = '<target><webApp><id>' + scan_id + '</id>'
    content = '''
    </webApp>
    <webAppAuthRecord>
    <isDefault>true</isDefault>
    </webAppAuthRecord>
    <scannerAppliance>
    <type>INTERNAL</type>
    <friendlyName>CB_Scanner_Xen</friendlyName>
    </scannerAppliance>
    </target>
    <profile>
    '''
    profile_id = '<id>' + args.profile_id + '</id> </profile>'

    parameters = ServiceRequest_xml_header + web_scan_name + scan_type + scan_id_content + content + profile_id + '\n' + ServiceRequest_xml_footer
    logger.debug('Scan parameters: %s', parameters)

    xml_output = qgc.request(call, parameters)
    root = objectify.fromstring(xml_output.encode('utf-8'))
    logger.debug('Xml output from launching scan: %s', xml_output.encode('utf-8'))

    # Need to check update results
    if root.responseCode != 'SUCCESS':
        logger.error('Error found when launching scan: %s', root.responseErrorDetails.errorMessage.text)
        sys.exit(1)
    else:
        SCAN_ID = root.data.WasScan.id.text
        logger.debug('Scan launch result: %s', xml_output.encode('utf-8'))

    # Get scan status
    # Exit the loop after one hour based on cancelAfterNHours value above.
    # Sometime, scan may get stuck in various states even when it is cancelled.
    call = '/status/was/wasscan' + '/' + SCAN_ID
    sleep_time = 60
    count=0

    while True:
        count=count+1
        xml_output = qgc.request(call, http_method='get')
        scan_root = objectify.fromstring(xml_output.encode('utf-8'))
        if scan_root.responseCode != 'SUCCESS':
            # Unable to obtain scan status if SCAN_ID is invalid or scan is deleted.
            logger.error('Error found when getting scan result: %s', scan_root.responseErrorDetails.errorMessage.text)
            logger.error('Scan result response code: %s', scan_root.responseCode)
            sys.exit(1)

        if count<=60:
            if scan_root.data.WasScan.status != 'FINISHED':
                time.sleep(sleep_time)
                logger.info('Wait for scan to finish.  Current scan status: %s', scan_root.data.WasScan.status)
                logger.info('Sleep for 60 seconds... %s', sleep_time)
            else:
                break
        else:
            logger.error('Scan did not finish in expected time frame. aborting...')
            logger.error('Scan result: %s', xml_output.encode('utf-8'))
            sys.exit(1)

    try:
        logger.info('Scan finished successfully! Scan id: %s', scan_root.data.WasScan.id.text)
        return scan_root.data.WasScan.id.text
    except AttributeError as error:
        logger.error('Error found when looking up scan_root.data.WasScan.id.text: %s',error)
        sys.exit(1)

def get_report_status(qgc, report_id):
    call = '/status/was/report/' + report_id
    xml_output = qgc.request(call, http_method='get')
    root = objectify.fromstring(xml_output.encode('utf-8'))
    logger.debug('Report status: %s', xml_output.encode('utf-8'))
    try:
        return root.data.Report.status
    except AttributeError as error:
        logger.error('Error found when returning root.data.Report.status: %s',error)
        sys.exit(1)

# template id 68837, is the default Scan Report template under our account.
def generate_report(qgc, args, WAS_SCAN_ID):
    ''' Generate scan report from scan_id '''

    call = '/create/was/report'
    ServiceRequest_xml_header = '''
    <ServiceRequest>
    <data>
    <Report>
    <name><![CDATA[with all parameters PDF]]></name>
    <description><![CDATA[A simple scan report]]></description>
    <format>PDF</format>
    <type>WAS_SCAN_REPORT</type>
    <template>
    <id>68837</id>
    </template>
    <config>
    <scanReport>
      <target>
    '''
    ServiceRequest_xml_footer = '''
      </target>
      </scanReport>
      </config>
        </Report>
      </data>
    </ServiceRequest>
    '''
    scan_id_content = '<scans><WasScan><id>' + WAS_SCAN_ID + '</id></WasScan></scans>'
    parameters = ServiceRequest_xml_header + scan_id_content + ServiceRequest_xml_footer

    xml_output = qgc.request(call, parameters)
    root = objectify.fromstring(xml_output.encode('utf-8'))
    logger.debug('Output from generating report: %s', xml_output.encode('utf-8'))

    if root.responseCode != 'SUCCESS':
        logger.error('Error found when generating report: %s', root.responseErrorDetails.errorMessage.text)
        sys.exit(1)
    else:
        REPORT_ID = root.data.Report.id.text
        logger.info('Report id: %s', REPORT_ID)

    # Download report
    if REPORT_ID:
        call = '/download/was/report/' + REPORT_ID
        sleep_time = 60
        while True:
            # get report status
            scan_status = get_report_status(qgc, REPORT_ID)
            if scan_status != 'COMPLETE':
                time.sleep(sleep_time)
                logger.info('Sleeping ... %s', sleep_time)
            else:
                break

        output = qgc.request(call, http_method='get')
        pdf_report_name = "Scan_Report_" + args.web_name + '_' + args.bld_num + '_' + args.scan_type_name + '_' + REPORT_ID + ".pdf"
        with open(pdf_report_name, "wb") as report:
            report.write(output)
        logger.info('Report has been downloaded successfully: %s', pdf_report_name)


def main(args):

    # Setup connection to QualysGuard API.
    qgc = qualysapi.connect(args.qualys_config)
    current_time = datetime.datetime.now().strftime("%Y%m%d%H%M")
    logger.debug('Current Time: %s', current_time)

    webapp_id = update_scan_url(qgc, current_time, args)
    scan_id = scan_report(qgc, current_time, args, webapp_id)
    generate_report(qgc, args, scan_id)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Couchbase WAS Scan Automation\n\n", formatter_class=RawTextHelpFormatter)
    parser.add_argument('--web-url', help="Host IP:port or Web URL:port.  e.g. http://ec2-54-187-77-59.us-west-2.compute.amazonaws.com:4984/\n", required=True)
    parser.add_argument('--webapp-id', help="WebApp ID. e.g. CBServer5.0: 2695834, SGW1.5.0:3084099 \n", required=True)
    parser.add_argument('--web-name', help="WebApp Name. e.g. SGW-1.5.0, Couchbase Server 5.0.0\n", required=True)
    parser.add_argument('--profile-id', help="Profile id to scan\n", required=True)
    parser.add_argument('--scan-type-name', help="VULNERABILITY or DISCOVERY\n", required=True)
    parser.add_argument('--bld-num', help="Jenkins build number\n", required=True)
    parser.add_argument('--qualys-config', help="Qualys API config filen\n", required=True)
    parser.add_argument('--debug', action='store_true', help="Print extra debug info\n")

    args = parser.parse_args()
    main(args)
