# Load libraries required by the Evernote OAuth sample applications
require 'oauth'
require 'oauth/consumer'

# Load Thrift & Evernote Ruby libraries
require "evernote_oauth"

# Client credentials
# Fill these in with the consumer key and consumer secret that you obtained
# from Evernote. If you do not have an Evernote API key, you may request one
# from http://dev.evernote.com/documentation/cloud/
OAUTH_CONSUMER_KEY = "ykominami-1-0694"
OAUTH_CONSUMER_SECRET = "a53c21b9fe88db96"

#SANDBOX = true
SANDBOX = false
