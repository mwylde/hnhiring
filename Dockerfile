FROM ruby:2.4-alpine

RUN apk update && apk add ca-certificates wget && update-ca-certificates

RUN apk add --virtual build-dependencies ruby-dev build-base
RUN apk add python

ENV HOME /
ENV CLOUDSDK_PYTHON_SITEPACKAGES 1
RUN wget https://dl.google.com/dl/cloudsdk/channels/rapid/google-cloud-sdk.zip && unzip google-cloud-sdk.zip && rm google-cloud-sdk.zip
RUN google-cloud-sdk/install.sh --usage-reporting=true --path-update=true --bash-completion=true --rc-path=/.bashrc

RUN google-cloud-sdk/bin/gcloud config set --installation component_manager/disable_update_check true
RUN sed -i -- 's/\"disable_updater\": false/\"disable_updater\": true/g' /google-cloud-sdk/lib/googlecloudsdk/core/config.json
RUN mkdir /.ssh
ENV PATH /google-cloud-sdk/bin:$PATH
VOLUME ["/.config"]

RUN mkdir /usr/app
RUN mkdir /usr/data
WORKDIR /usr/app

ADD Gemfile .
ADD Gemfile.lock .
ADD get_data.rb .
ADD upload_data.sh .

RUN gem install bundler --no-ri --no-rdoc && \
    cd /usr/app ; bundle install --without development test && \
    apk del build-dependencies

CMD ["/bin/sh", "-c", "/usr/app/get_data.rb /usr/data && ./upload_data.sh /usr/data"]
