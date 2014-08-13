# Pull base image
FROM dockerfile/java
MAINTAINER ryt0001

# locale
RUN \
	echo "Asia/Tokyo" > /etc/timezone && \
	rm -f /etc/localtime && \
	ln -s /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

# td-agent
ADD http://packages.treasure-data.com/debian/RPM-GPG-KEY-td-agent /var/tmp/
RUN apt-key add /var/tmp/RPM-GPG-KEY-td-agent && \
    echo "deb http://packages.treasure-data.com/precise/ precise contrib" > /etc/apt/sources.list.d/treasure-data.list

# elasticsearch
ADD http://packages.elasticsearch.org/GPG-KEY-elasticsearch /var/tmp/
RUN apt-key add /var/tmp/GPG-KEY-elasticsearch && \
    echo "deb http://packages.elasticsearch.org/elasticsearch/1.3/debian stable main" > /etc/apt/sources.list.d/elasticsearch.list

# apt-get
RUN sed -i s/us.archive.ubuntu.com/ftp.jaist.ac.jp/ /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -qq -y --force-yes td-agent elasticsearch apache2 libcurl4-openssl-dev make

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

# Define mountable directories
VOLUME {"/var/lib/elasticsearch","/var/log/elasticsearch"}

# add files
ADD conf/td-agent.conf /etc/td-agent/
ADD conf/apache.conf /etc/httpd/conf.d/

# Expose Elasticsearch ports.
#   9200: HTTP, 9300: transport
EXPOSE 9200
EXPOSE 9300

# Expose Fluentd port.
EXPOSE 24284

# Expose Apache http port
EXPOSE 80