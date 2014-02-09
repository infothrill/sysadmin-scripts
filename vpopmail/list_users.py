#!/usr/bin/env python

"""
Quick script to list all email users registered with the vpopmail mysql db
"""

import os
import MySQLdb

def mysqlConnect(host, user, passwd, db):
    connection = MySQLdb.Connect(host = host, user = user, passwd = passwd, db = db)
    return connection

def getMySqlCredtentialsFromVpopmail(vpopmail_dir = '/home/vpopmail'):
    cfgfile = open(os.path.join(vpopmail_dir, 'etc', 'vpopmail.mysql'))
    # host|port|user|password|database
    credlist = []
    for line in cfgfile:
         if line.find("#") == -1: # non-comment line
             line = line.rstrip()
             credlist = line.split("|")
    creds = { "host": credlist[0], "port": credlist[1], "user": credlist[2], "passwd": credlist[3], "db": credlist[4] }
    return creds

def main():
    creds = getMySqlCredtentialsFromVpopmail()
    dbh = mysqlConnect(**creds)
    cursor = dbh.cursor()
    cursor.execute("SELECT `pw_name`, `pw_domain` FROM vpopmail")
    result = cursor.fetchall()
    fields = cursor.description
    print fields
    #return 0
    for res in result:
        print res[0] + '@' + res[1]

if __name__ == '__main__':
    main()

