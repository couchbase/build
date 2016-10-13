#!/usr/bin/python
import sys
import socket
import time
import datetime
import boto3
import botocore
from optparse import OptionParser

class awssdk_instance():
    def __init__(self, iid):
        self.iid = iid

        # takes a long time for the instance to initialize itself
        # even though it says "running".
        self.post_start_wait = 240 #seconds

        self.boto_ec2_obj = boto3.resource('ec2')
        self.boto_inst_obj = self.boto_ec2_obj.Instance(iid)
        self.inst_state = None
        self.inst_tags = None
        self.up_since = 0

    def start(self, jenk_job):
        self._get_current_state()

        if self.inst_state.lower() == 'running':
            cur_job = self._get_job_name()
            new_tag = cur_job + ',' + jenk_job
            if cur_job == 'none':
                new_tag = jenk_job
            self.boto_ec2_obj.create_tags(Resources=[self.iid], Tags=[{'Key': 'jenkins-job', 'Value': new_tag}])
            return

        if self.inst_state.lower() == 'pending':
            print 'It has been started by another job'
            return

        if self.inst_state.lower() == 'stopping':
            self.boto_inst_obj.wait_until_stopped()
            self._get_current_state()

        if self.inst_state.lower() == 'stopped':
            self.boto_inst_obj.start()
            self.boto_inst_obj.wait_until_running()
            self.boto_ec2_obj.create_tags(Resources=[self.iid], Tags=[{'Key': 'jenkins-job', 'Value': jenk_job}])
            ip = self.boto_inst_obj.public_ip_address
            #self._wait_for_ssh(ip, self.post_start_wait)
            time.sleep(self.post_start_wait)
            print ip
            return

    def done(self, jenk_job):
        self._get_current_state()
        cur_job_list = self._get_job_name().split(',')
        if jenk_job in cur_job_list:
            cur_job_list.remove(jenk_job)
        new_job_tag = 'none'
        if cur_job_list:
            new_job_tag = ','.join(cur_job_list)

        self.boto_ec2_obj.create_tags(Resources=[self.iid], Tags=[{'Key': 'jenkins-job', 'Value': new_job_tag}])
        return

    def stop(self):
        self.boto_inst_obj.stop()
        self.boto_ec2_obj.create_tags(Resources=[self.iid], Tags=[{'Key': 'jenkins-job', 'Value': 'none'}])
        self.boto_inst_obj.wait_until_stopped()
        return

    def terminate(self):
        self.boto_inst_obj.terminate()
        self.boto_inst_obj.wait_until_terminated()
        return

    def status(self):
        self._get_current_state()
        if self.inst_state.lower() == 'stopped' or self.inst_state.lower() == 'stopping':
            print 'Instance stopped/stopping'
            return

        job_name = self._get_job_name()
        if job_name == 'none':
            print 'Instance running for %d hours; but not used by any job currently' %self.up_since
        else:
            print 'Instance running for %d hours; but currently in use by %s' %(up_since, job_name)


    def monitor(self, idle_wait_time=900):
        self._get_current_state()
        if self.inst_state.lower() == 'stopped' or self.inst_state.lower() == 'stopping':
            self.stop() # to rest jenkins-job tag, just in case
            return

        job_name = self._get_job_name()
        if job_name == 'none':
            time.sleep(idle_wait_time)
            self._get_current_state()
            job_name = self._get_job_name()

            if job_name == 'none':
                print 'Stopping instance %s is running and not used by any sdk build jobs' %self.iid
                self.stop()
        else:
                print 'Instance running, but currently in use'

        return True

    def _wait_for_ssh(self, ip, timeout):
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        waited_for = 0
        while True:
            try:
                sock.connect((ip, 22))
                break
            except socket.error as e:
                if waited_for < timeout:
                    time.sleep(15)
                    waited_for += 15
                    continue
                else:
                    break


    def _get_job_name(self):
        job_name = 'none'
        for t in self.inst_tags:
            if t['Key'] == 'jenkins-job':
                job_name = t['Value']
        return job_name

    def _get_current_state(self):
        try:
            self.boto_inst_obj.reload()
            self.inst_state = self.boto_inst_obj.state['Name']
            self.inst_tags = self.boto_inst_obj.tags
            launch_time = self.boto_inst_obj.launch_time
            launch_time_int = int(time.mktime(launch_time.timetuple()))
            utc_now_int = int(time.mktime(datetime.datetime.utcnow().timetuple()))
            self.up_since = (utc_now_int - launch_time_int) / 3600
            #print self.inst_state
            #print self.inst_tags
        except botocore.exceptions.ClientError, e:
            if e.message.find('InvalidInstanceID') > 0:
                print 'There is no such instance [%s] on AWS, perhaps we are given a wrong argument?' %self.iid
                sys.exit(1)

            print 'Exception:',
            print e
            sys.exit(2)

if __name__ == '__main__':
    parser = OptionParser()
    parser.add_option("-i", "--instance-id", dest="iid",
                      help="Instance id used by winsdk build", metavar="INSTANCE ID")
    parser.add_option("-j", "--job-name", dest="job",
                      help="Jenkins job name. Applicable for start/done command", metavar="JOBNAME")
    parser.add_option("-c", "--command", dest="cmd",
                      help="Valid values: start, done, status, monitor, terminate", metavar="COMMAND")
    parser.add_option("-w", "--wait-time", dest="wait_time", default=900, type=int,
                      help="Applicable only for monitor command. Wait time to see if any build will get kicked within this time so we don't have to kill the instance.", metavar="SECONDS")

    (options, args) = parser.parse_args()
    if options.iid:
        asi = awssdk_instance(options.iid)
        if options.cmd:
            if options.cmd == 'start' and options.job:
                asi.start(options.job)
            elif options.cmd == 'done' and options.job:
                asi.done(options.job)
            elif options.cmd == 'monitor':
                asi.monitor(options.wait_time)
            elif options.cmd == 'status':
                asi.status()
            elif options.cmd == 'terminate':
                asi.terminate()
