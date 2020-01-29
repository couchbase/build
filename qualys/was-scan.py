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
    logger.info('xml_output: %s', xml_output)
    root = objectify.fromstring(xml_output)

    # Need to check update results
    if root.responseCode != 'SUCCESS':
        logger.error('Error Found: %s', root.responseErrorDetails.errorMessage.text)
    else:
        logger.info('Successfully updated webapp: %s', root.data.WebApp.id.text)
        return root.data.WebApp.id.text


def scan_report(qgc, current_time, args, scan_id):
    call = '/launch/was/wasscan'

    ServiceRequest_xml_header = '''
    <ServiceRequest>
            <data>
              <WasScan>
    '''
    ServiceRequest_xml_footer = '''
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
    logger.debug('parameters: %s', parameters)

    xml_output = qgc.request(call, parameters)
    root = objectify.fromstring(xml_output)
    logger.debug('xml_output: %s', xml_output)

    # Need to check update results
    if root.responseCode != 'SUCCESS':
        logger.error('Error Found: %s', root.responseErrorDetails.errorMessage.text)
        sys.exit(1)
    else:
        SCAN_ID = root.data.WasScan.id.text
        logger.info('id: %s', xml_output)

    # get scan status
    call = '/status/was/wasscan' + '/' + SCAN_ID
    sleep_time = 180
    while True:
        xml_output = qgc.request(call)
        scan_root = objectify.fromstring(xml_output)
        if scan_root.data.WasScan.status != 'FINISHED':
            time.sleep(sleep_time)
            logger.info('Sleeping ... %s', sleep_time)
        else:
            break

    #logger.debug('xml_output: %s', xml_output)

    # Need to check update results
    if scan_root.responseCode != 'SUCCESS':
        logger.error('Error Found: %s', scan_root.responseErrorDetails.errorMessage.text)
        sys.exit(1)
    # elif scan_root.responseCode == 'SUCCESS' and scan_root.data.WasScan.summary is not None:
    #    print("Error Found: {}".format(scan_root.data.WasScan.summary.resultsStatus.text))
    #    sys.exit(1)
    else:
        logger.info('Scan finished successfully!')
        logger.info('Scan id: %s', scan_root.data.WasScan.id.text)
        return scan_root.data.WasScan.id.text


def get_report_status(qgc, report_id):
    call = '/status/was/report/' + report_id
    xml_output = qgc.request(call)
    root = objectify.fromstring(xml_output)
    return root.data.Report.status


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
    <config>
    <scanReport>
      <target>
    '''
    ServiceRequest_xml_footer = '''
      </target>
      <display>
    <contents> <ScanReportContent>DESCRIPTION</ScanReportContent>
    <ScanReportContent>SUMMARY</ScanReportContent>
    <ScanReportContent>GRAPHS</ScanReportContent>
    <ScanReportContent>RESULTS</ScanReportContent>
    <ScanReportContent>INDIVIDUAL_RECORDS</ScanReportContent>
    <ScanReportContent>RECORD_DETAILS</ScanReportContent>
    <ScanReportContent>ALL_RESULTS</ScanReportContent>
    <ScanReportContent>APPENDIX</ScanReportContent>
    </contents>
    <graphs>
    <ScanReportGraph>VULNERABILITIES_BY_SEVERITY</ScanReportGraph>
    <ScanReportGraph>VULNERABILITIES_BY_GROUP</ScanReportGraph>
    <ScanReportGraph>VULNERABILITIES_BY_OWASP</ScanReportGraph>
    <ScanReportGraph>VULNERABILITIES_BY_WASC</ScanReportGraph>
    <ScanReportGraph>SENSITIVE_CONTENTS_BY_GROUP</ScanReportGraph>
    </graphs>
    <groups> <ScanReportGroup>URL</ScanReportGroup>
    <ScanReportGroup>GROUP</ScanReportGroup>
    <ScanReportGroup>OWASP</ScanReportGroup>
    <ScanReportGroup>WASC</ScanReportGroup>
    <ScanReportGroup>STATUS</ScanReportGroup>
    <ScanReportGroup>CATEGORY</ScanReportGroup>
    <ScanReportGroup>QID</ScanReportGroup>
        </groups>
        <options>
          <rawLevels>true</rawLevels>
        </options>
      </display>
      <filters>
        <status>
            <ScanFindingStatus>NEW</ScanFindingStatus>
            <ScanFindingStatus>ACTIVE</ScanFindingStatus>
            <ScanFindingStatus>REOPENED</ScanFindingStatus>
            <ScanFindingStatus>FIXED</ScanFindingStatus>
        </status>
      </filters>
      </scanReport>
      </config>
        </Report>
      </data>
    </ServiceRequest>
    '''
    scan_id_content = '<scans><WasScan><id>' + WAS_SCAN_ID + '</id></WasScan></scans>'
    parameters = ServiceRequest_xml_header + scan_id_content + ServiceRequest_xml_footer

    xml_output = qgc.request(call, parameters)
    root = objectify.fromstring(xml_output)
    logger.debug('xml_output: %s', xml_output)

    if root.responseCode != 'SUCCESS':
        logger.error('Error Found: %s', root.responseErrorDetails.errorMessage.text)
        sys.exit(1)
    else:
        REPORT_ID = root.data.Report.id.text
        logger.debug('Report id: %s', REPORT_ID)

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

        output = qgc.request(call)
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
