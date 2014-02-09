-- $Id: mysql.sql,v 1.1 2004/04/23 13:41:07 pkremer Exp $
-- MySQL dump 9.10
--
-- Host: localhost    Database: sql2data
-- ------------------------------------------------------
-- Server version	4.0.18-log

--
-- Table structure for table `ddns_domains`
--

CREATE TABLE `ddns_domains` (
  `domain_id` int(11) NOT NULL default '0',
  `domain` varchar(100) NOT NULL default '',
  `status` enum('active','inactive') NOT NULL default 'inactive',
  KEY `domain_id` (`domain_id`,`domain`)
) TYPE=MyISAM;

--
-- Dumping data for table `ddns_domains`
--


--
-- Table structure for table `ddns_records`
--

CREATE TABLE `ddns_records` (
  `domain_id` int(11) NOT NULL default '0',
  `record_id` int(11) NOT NULL auto_increment,
  `host` varchar(100) NOT NULL default '',
  `type` char(1) default NULL,
  `val` varchar(100) default NULL,
  `distance` int(4) default '0',
  `ttl` int(11) NOT NULL default '86400',
  UNIQUE KEY `records_id` (`record_id`),
  KEY `records_idx` (`record_id`,`domain_id`,`host`)
) TYPE=MyISAM;

--
-- Dumping data for table `ddns_records`
--


