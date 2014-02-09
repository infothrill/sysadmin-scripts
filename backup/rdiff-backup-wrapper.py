#!/usr/bin/env python

legalMatters = """
 Copyright (c) 2007, Paul Kremer
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, 
 are permitted provided that the following conditions are met:
 *  Redistributions of source code must retain the above copyright notice, 
    this list of conditions and the following disclaimer.
 *  Redistributions in binary form must reproduce the above copyright notice, 
    this list of conditions and the following disclaimer in the documentation 
    and/or other materials provided with the distribution.
 *  Neither the name of etoy.CORPORATION nor the names of its contributors may be used to 
    endorse or promote products derived from this software without specific prior 
    written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY 
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT 
 SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT 
 OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
"""

author = """Paul Kremer, 2007"""

from ConfigParser import SafeConfigParser
from optparse import OptionParser
import logging

__configObject = None # holder for a Config object
def getConfig(configfile = None):
    """
    Returns an instance of Config()
    """
    global __configObject
    from os import environ, path
    if __configObject == None:
        if not configfile == None:
            cfgfile = configfile
        else:
            cfgfile = path.join(getAppHomePath(), "config.ini")
        __configObject = SafeConfigParser()
        __configObject.read(cfgfile)
    return __configObject

def isMacOSX():
    import re, platform
    darwin = re.compile('Darwin')
    if darwin.match(platform.system()):
        return True
    else:
        return False
    
def getAppHomePath():
    from os import environ, path, mkdir
    home = environ["HOME"]
    if isMacOSX():
        homepath = path.join(home, 'Library', 'Application Support', 'rdiff-backup-wrapper')
    else:
        homepath = path.join(home, ".rdiff-backup-wrapper")
    if not path.exists(homepath):
        mkdir(homepath)
    return homepath

def getAppLogPath():
    from os import environ, path, mkdir
    if isMacOSX():
        home = environ["HOME"]
        logpath = path.join(home, 'Library', 'Logs', 'rdiff-backup-wrapper')
    else:
        logpath = path.join(getAppHomePath(), 'log')
    if not path.exists(logpath):
        mkdir(logpath)
    return logpath

def runProc(args = None, quiet = False):
    import subprocess
    from os import environ
    if args == None:
        raise NameError, "args must be set to run a program!"
    #print args
    logging.debug("executing %s" % " ".join(args))
    proc = subprocess.Popen(args, stdout = subprocess.PIPE, stderr = subprocess.PIPE)
    res = proc.wait()
#    res = subprocess.call(args)
    if not res == 0 and quiet == False:
        logging.error("error while executing '%s'" % " ".join(args))
        logging.error("Non-zero exit code: '%s'" % res)
        logging.error("STDOUT is:")
        for line in proc.stdout.readlines():
            logging.error(line.rstrip('\n'))
        logging.error("STDERR is:")
        for line in proc.stderr.readlines():
            logging.error(line.rstrip('\n'))
    else:
        if quiet == False:
            for line in proc.stdout.readlines():
                logging.info(line.rstrip('\n'))
    if res == 0:
        return True
    else:
        return False

def getCommonConfigValues(cfg):
    from string import strip

    common_options = {'sets': None}
    required_common_options = {'sets': None}
    # make sure required options are set by simply trying to get() them:
    for c in required_common_options:
        cfg.get('common', c)

    sets_str = cfg.get('common', 'sets')
    setnames = map(strip, sets_str.split(","), ' ')
    common_options['sets'] = setnames
    return common_options

def getSetConfigValues(cfg, setname, common_options):
    import re, os
    set_options = {'name': None, 'source': None, 'destination': None}
    # make sure required options are set by simply trying to get() them:
    for c in set_options:
        set_options[c] = cfg.get(setname, c, False, common_options)
    # now fetch all given options:
    excludeoptionmatch = re.compile("^--exclude.*")
    for c in cfg.options(setname):
        set_options[c] = cfg.get(setname, c, False, common_options)
        set_options[c] = set_options[c].split(os.linesep) # multi-line options

        # remove double slashes from filenames:
        if excludeoptionmatch.match(c):
            for i in range(len(set_options[c])):
                set_options[c][i] = os.path.expanduser(set_options[c][i])
                while not set_options[c][i].find(os.sep+os.sep) == -1:
                    set_options[c][i]  = set_options[c][i].replace(os.sep + os.sep, os.sep)
        if len(set_options[c]) == 1:
            set_options[c] = set_options[c][0]
        elif len(set_options[c]) == 0:
            set_options[c] = ''

    set_options['source'] = os.path.expanduser(set_options['source'])
    set_options['destination'] = os.path.expanduser(set_options['destination'])
    if set_options.has_key('syncresult'):
        set_options['syncresult'] = os.path.expanduser(set_options['syncresult'])
    return set_options

def pingHost(host):
    args = ['ping', '-c', '1', host]
    res = runProc(args, True)
    #print "Ping host %s returned:" % host
    #print res
    return res

def doBackupWithOptions(copt, dopt):
    import re, string
    from types import ListType
    m = re.compile('^\-\-.*')
    additional_run_options = ['--remove-older-than']
    additional_run = []
    forbidden_options = ['-r', '--restore-as-of']
    cmdlineoptions = []
    for k in dopt:
        if m.match(k): # it's a command line option for rdiff-backup!
            if k in additional_run_options:
                additional_run = [k, dopt[k]]
            elif k in forbidden_options:
                pass
            else:
                if type(dopt[k]) is ListType:
                    #print "FOUND LIST"
                    for val in dopt[k]:
                        cmdlineoptions.append(k)
                        cmdlineoptions.append(val)
                else:
                    cmdlineoptions.append(k)
                    if len(dopt[k]) > 0: # some command line arguments are switches and take no value!
                        cmdlineoptions.append(dopt[k])
    cmdlineoptions.append(dopt['source'])
    cmdlineoptions.append(dopt['destination'])
    cmdlineoptions.insert(0, 'rdiff-backup')
    logging.info("%s ---> %s" % (dopt['source'], dopt['destination']))
    # do run!
    backupRunResult = runProc(cmdlineoptions)
    # if successfull:
    if backupRunResult == True:
        if len(additional_run) > 0:
            additional_run.append(dopt['destination'])
            additional_run.insert(0, 'rdiff-backup')
            logging.info("Cleanup: %s" % " ".join(additional_run))
            backupRunResult = runProc(additional_run)
    return backupRunResult
    
def passPingCheck(setoptions):
    if (setoptions.has_key('pingcheck') and pingHost(setoptions['pingcheck'])) or (not setoptions.has_key('pingcheck')):
        return True
    else:
        logging.warn("could not ping host '%s'" % setoptions['pingcheck'])
        return False

def passDirCheck(setoptions):
    import os
    if (setoptions.has_key('dircheck') and os.path.exists((setoptions['dircheck']))) or (not setoptions.has_key('dircheck')):
        return True
    else:
        logging.warn("error: directory '%s' does not exist" % setoptions['dircheck'])
        return False
    
def setupLogging(verbosity = 1, logfile = 'main.log', logcount = 62):
    from logging import handlers
    import os
    if logfile == None:
        logfile = 'main.log'
    if logcount == None:
        logcount = 62
    # set up logging
    logging.basicConfig(level=logging.DEBUG, filename = os.devnull, filemode = 'w')

    # define a Handler which writes messages to sys.stderr
    console = logging.StreamHandler()
    formatter = logging.Formatter('%(levelname)-8s %(message)s')
    console.setFormatter(formatter)
    if verbosity == 0:
        # simply no logging to console whatsoever ;-)
        pass
    elif verbosity == 2:
        console.setLevel(logging.DEBUG)
        logging.getLogger().addHandler(console)
    else: # normal : 1
        console.setLevel(logging.ERROR)
        logging.getLogger().addHandler(console)

    if logfile == os.devnull:
        fileH = logging.FileHandler(os.devnull)
    else:
        fileH = handlers.RotatingFileHandler(os.path.join(getAppLogPath(), logfile) , backupCount = logcount)
        fileH.doRollover() # rotate logfiles straight off!

    fileH.setLevel(logging.INFO)
    formatterFile = logging.Formatter('%(asctime)s %(levelname)-8s %(message)s')
    fileH.setFormatter(formatterFile)
    logging.getLogger().addHandler(fileH)

def versionCheck():
    import platform, sys
    (major,minor,patchlevel) = platform.python_version_tuple()
    major = int(major)
    minor = int(minor)
    if (major <= 2 and minor < 4 ):
        print "this script requires Python version 2.4 or newer. Sorry!"
        sys.exit(256)


def main():
    import sys, os
    versionCheck()
    parser = OptionParser()
    parser.add_option("-c", "--config", dest="configfile", help="alternative config file", default='')
    parser.add_option("-v", "--verbose", dest="verbose", help="be verbose", action="store_true" ,default=False)
    parser.add_option("-q", "--quiet", dest="quiet", help="be quiet", action="store_true" ,default=False)
    (options, args) = parser.parse_args()

    verbosity = 1 # normal
    if options.quiet == True:
        verbosity = 0
    if options.verbose == True:
        verbosity = 2

    if len(options.configfile) > 0:
        cfg = getConfig(options.configfile)
    else:
        cfg = getConfig()

    thelogfile = None
    if cfg.has_option('common', 'logfile'):
        thelogfile = cfg.get('common', 'logfile')

    if cfg.has_option('common', 'logcount'):
        logcount = cfg.getint('common', 'logcount')
    else:
        logcount = None

    setupLogging(verbosity = verbosity, logfile = thelogfile, logcount = logcount)

    logging.debug('starting')

    overAllSuccess = True
    common_options = getCommonConfigValues(cfg)
    for set in common_options['sets']:
        logging.info("===START==================[ %s ]===========================", set)
        setoptions = getSetConfigValues(cfg, 'set_' + set, common_options)
        if passPingCheck(setoptions) and passDirCheck(setoptions):
            result = doBackupWithOptions(common_options, setoptions)
            if result == False:
                logging.error("error in backup set '%s'" % set)
                overAllSuccess = False
        logging.info("===END==================[ %s ]===========================", set)
    # done with backups, now sync the logs to the optional destination:
    logging.info('ended with success == %s' % overAllSuccess)

    # TODO: currently we sync ALL available logs in logPath, but maybe they should be specific to the config file used?
    if cfg.has_option('common', 'synclogs'):
        destination = cfg.get('common', 'synclogs')
        destination = os.path.expanduser(destination)
        src = getAppLogPath()
        if not src.endswith(os.sep): src += os.sep
        if not destination.endswith(os.sep): destination += os.sep
        runProc(['rsync','-aupz', src, destination])

    if overAllSuccess == False:
        sys.exit(256)

if __name__ == '__main__':
    main()
