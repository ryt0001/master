# Pull base image
FROM dockerfile/java
MAINTAINER ryt0001

# locale
RUN \
	echo "Asia/Tokyo" > /etc/timezone && \
	rm -f /etc/localtime && \
	ln -s /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

# Add repository for td-agent
ADD http://packages.treasure-data.com/debian/RPM-GPG-KEY-td-agent /var/tmp/
RUN apt-key add /var/tmp/RPM-GPG-KEY-td-agent && \
    echo "deb http://packages.treasure-data.com/precise/ precise contrib" > /etc/apt/sources.list.d/treasure-data.list

# Add repository for elasticsearch
ADD http://packages.elasticsearch.org/GPG-KEY-elasticsearch /var/tmp/
RUN apt-key add /var/tmp/GPG-KEY-elasticsearch && \
    echo "deb http://packages.elasticsearch.org/elasticsearch/1.3/debian stable main" > /etc/apt/sources.list.d/elasticsearch.list

# Install (apt-get)
RUN sed -i s/us.archive.ubuntu.com/ftp.jaist.ac.jp/ /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -qq -y --force-yes td-agent elasticsearch apache2 apache2-utils libcurl4-openssl-dev make supervisor

# Install Kibana
ENV _KIBANA_FILENAME kibana-3.1.0
ADD https://download.elasticsearch.org/kibana/kibana/${_KIBANA_FILENAME}.tar.gz /var/tmp/ 
RUN cd /var/tmp/ && \
    tar xzf /var/tmp/${_KIBANA_FILENAME}.tar.gz && \
    mv /var/tmp/${_KIBANA_FILENAME} /var/www/html/kibana

# Install Elasticsearch plugins (Head, Marvel, fluentd-plugin-elasticsearch)
RUN /usr/share/elasticsearch/bin/plugin -i mobz/elasticsearch-head
RUN /usr/share/elasticsearch/bin/plugin -i elasticsearch/marvel/latest
RUN /usr/lib/fluent/ruby/bin/fluent-gem install --no-ri --no-rdoc fluent-plugin-elasticsearch
RUN /usr/lib/fluent/ruby/bin/fluent-gem install --no-ri --no-rdoc fluent-plugin-secure-forward

# Modify config.js for kibana
RUN sed -i 's%"http://"+window.location.hostname+":9200"%"http://"+window.location.hostname+"/es/"%' /var/www/html/kibana/config.js

# Define mountable directories
VOLUME {"/var/lib/elasticsearch","/var/log/elasticsearch"}

# Add .conf files
ADD conf/supervisord.conf /etc/supervisor/conf.d/
ADD conf/td-agent.conf /etc/td-agent/
ADD conf/site.conf /etc/apache2/sites-available/
ADD conf/proxy.conf /etc/apache2/conf-available/
RUN cd /etc/apache2/conf-enabled/ && ln -s /etc/apache2/conf-available/proxy.conf proxy.conf

# Enable proxy modules
RUN \
a2enmod proxy && \
a2enmod proxy_http && \
a2enmod auth_digest 

# enable site config for digest authentication
RUN a2dissite 000-default && a2ensite site

# Start services with Supervisor
CMD \
	/usr/bin/supervisord && \
	# Create .htdigest for digest authentication 
	htdigest -c /etc/apache2/.htdigest 'Authentication required' admin 

# Expose Elasticsearch ports. (9200 HTTP, 9300 transport)
EXPOSE 9200
EXPOSE 9300

# Expose Fluentd port.
EXPOSE 24284

# Expose Apache http port
EXPOSE 80
