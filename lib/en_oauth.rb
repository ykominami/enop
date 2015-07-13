##
# Copyright 2012 Evernote Corporation. All rights reserved.
##

require 'sinatra'
require 'sinatra/reloader'
enable :sessions

# Load our dependencies and configuration settings
$LOAD_PATH.push(File.expand_path(File.dirname(__FILE__)))

#set :port, 4569
set :port, 4570

require "evernote_config.rb"

##
# Verify that you have obtained an Evernote API key
##
before do
  if OAUTH_CONSUMER_KEY.empty? || OAUTH_CONSUMER_SECRET.empty?
    halt '<span style="color:red">Before using this sample code you must edit evernote_config.rb and replace OAUTH_CONSUMER_KEY and OAUTH_CONSUMER_SECRET with the values that you received from Evernote. If you do not have an API key, you can request one from <a href="http://dev.evernote.com/documentation/cloud/">dev.evernote.com/documentation/cloud/</a>.</span>'
  end
end

helpers do
  def auth_token
    session[:access_token].token if session[:access_token]
  end

  def client
    @client ||= EvernoteOAuth::Client.new(token: auth_token, consumer_key:OAUTH_CONSUMER_KEY, consumer_secret:OAUTH_CONSUMER_SECRET, sandbox: SANDBOX)
  end

  def user_store
    @user_store ||= client.user_store
  end

  def note_store
    @note_store ||= client.note_store
  end

  def en_user
    user_store.getUser(auth_token)
  end

  def notebooks
    @notebooks ||= note_store.listNotebooks(auth_token)
  end

  def total_note_count
    filter = Evernote::EDAM::NoteStore::NoteFilter.new
    counts = note_store.findNoteCounts(auth_token, filter, false)
    notebooks.inject(0) do |total_count, notebook|
      total_count + (counts.notebookCounts[notebook.guid] || 0)
    end
  end

  def notebooks_hash
    @notebooks_hash ||= {}
    if @notebooks_hash.size != notebooks.size
      notebooks.each do |x|
        @notebooks_hash[x.name] = x
      end
    end
    @notebooks_hash
  end

  def notes(guid)
    filter = Evernote::EDAM::NoteStore::NoteFilter.new
#    filter.notebookGuid = @notebook.guid
    filter.notebookGuid = guid
    @found_n = note_store.findNotes(auth_token, filter, 0 , 100 )
#    @found_notes = @found_n.notes
    @found_n.notes
  end
end

##
# Index page
##
get '/' do
  erb :index
end

##
# Reset the session
##
get '/reset' do
  session.clear
  redirect '/'
end

##
# Obtain temporary credentials
##
get '/requesttoken' do
  callback_url = request.url.chomp("requesttoken").concat("callback")
  begin
    session[:request_token] = client.request_token(:oauth_callback => callback_url)
    redirect '/authorize'
  rescue => e
    @last_error = "3 Error obtaining temporary credentials: #{e.message}"
    erb :error
  end
end

##
# Redirect the user to Evernote for authoriation
##
get '/authorize' do
  if session[:request_token]
    redirect session[:request_token].authorize_url
  else
    # You shouldn't be invoking this if you don't have a request token
    @last_error = "Request token not set."
    erb :error
  end
end

##
# Receive callback from the Evernote authorization page
##
get '/callback' do
  unless params['oauth_verifier'] || session['request_token']
    @last_error = "Content owner did not authorize the temporary credentials"
    halt erb :error
  end
  session[:oauth_verifier] = params['oauth_verifier']
  begin
    session[:access_token] = session[:request_token].get_access_token(:oauth_verifier => session[:oauth_verifier])
    redirect '/list'
  rescue => e
    @last_error = '2 Error extracting access token'
    erb :error
  end
end


##
# Access the user's Evernote account and display account data
##
get '/list' do
  begin
    # Get notebooks
    session[:notebooks] = notebooks.collect{ |notebook|
      [ notebook.name , notebook.guid ]
    }
#    session[:notebooks] = notebooks.map(&:name)
    # Get username
    session[:username] = en_user.username
    # Get total note count
    session[:total_notes] = total_note_count
    erb :index
  rescue => e
#    @last_error = "Error listing notebooks: #{e.message}"
    @last_error = "1 Error listing notebooks: #{e}"
    erb :error
  end
end

##
# 
##
get '/notebook/:name/:guid' do
  begin
    session[:notebook_name] = params[:name]
    session[:notebook_guid] = params[:guid]

#    @notebook = notebooks_hash[ params[:name] ]
    @found_notes = notes( params[:guid] )

    erb :notes
  rescue => e
    @last_error = "0 Error listing notebook: #{e.message}"
    erb :error
  end
end

get '/create_note/:name/:guid' do
  begin
    ENML_HEADER = <<HEADER
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">
HEADER

    note_content = <<CONTENT
#{ENML_HEADER}
<en-note>Hello, my Evernote (from Ruby)!</en-note>
CONTENT

    note = Evernote::EDAM::Type::Note.new
    note.title = "Note Title"
    note.notebookGuid = params[:guid]
    note.content = note_content
    note_store.createNote( auth_token , note)
    @found_notes = notes(session[:notebook_guid])

    erb :notes
  rescue => e
    @last_error = "0 Error listing notebook: #{e.message}"
    erb :error
  end
end


__END__

@@ index
<html>
<head>
  <title>Evernote Ruby Example App</title>
</head>
<body>
  <a href="/requesttoken">Click here</a> to authenticate this application using OAuth.
  <% if session[:notebooks] %>
  <hr />
  <h3>The current user is <%= session[:username] %> and there are <%= session[:total_notes] %> notes in their account</h3>
  <br />
  <h3>Here are the notebooks in this account:</h3>
  <ul>
    <% session[:notebooks].each do |notebook| %>
<% p session[:notebooks] %>
    <li><a href="/notebook/<%= notebook[0] %>/<%= notebook[1] %>"><%= notebook[0] %></a></li>
    <% end %>
  </ul>
  <% end %>
</body>
</html>

@@ error 
<html>
<head>
  <title>Evernote Ruby Example App &mdash; Error</title>
</head>
<body>
  <p>An error occurred: <%= @last_error %></p>
  <p>Please <a href="/reset">start over</a>.</p>
</body>
</html>

@@ notebook
<html>
<head>
</head>
<body>
    <table>
    <% @found_notes.collect do |x| %>
<tr>
<td>
<%= x.guid %>
</td>
<td>
<%= x.title %>
</td>
</tr>
    <% end %>
    </table>
<form action="/create_note" method="get">
<input type="text" name="val" value="1">
<input type="submit" value="Create Note">
</form>
</body>
</html>

@@ notes
<html>
<head>
</head>
<body>
    <table>
    <% @found_notes.collect do |x| %>
<tr>
<td>
<%= x.guid %>
</td>
<td>
<%= x.title %>
</td>
</tr>
    <% end %>
    </table>
<form action="/create_note/<%= session[:notebook_name] %>/<%= session[:notebook_guid] %>" method="get">
<input type="text" name="val" value="1">
<input type="submit" value="Create Note">
</form>
</body>
</html>

@@ notebook1
<html>
<head>
</head>
<body>
Notebook<p>
    <%= p @notebook.class %><p>
    <%= p @found_n.class %><p>
    <%= p @found_notes.class %><p>
  <ul>
    <% p @found_notes; @found_notes.each do |note| %>
    <li><a href="/note/<%= note.name %>/<%= note.guid %>"><%= note.name %></li>
    <% end %>
  </ul>
</body>
</html>

@@ note
<html>
<head>
</head>
<body>

</body>
</html>
