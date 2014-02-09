remote: data.cdb
	rsync -az -e ssh * secondary.dns.tld:/etc/tinydns/root/
data.cdb: data static_data
	/path/to/sql2data -c /path/to/sql2data.config -f -l -v
	/usr/local/bin/tinydns-data
