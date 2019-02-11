# -*- coding: utf-8 -*-
require 'evernote-thrift'
require 'csv'
require 'pp'
require 'openssl'
require 'forwardable'

module Enop
  class Enop

    def initialize( authToken , hs , opts, userStoreUrl = nil )
      # SSL認証を行わないように変更
      OpenSSL::SSL.module_eval{ remove_const(:VERIFY_PEER) }
      OpenSSL::SSL.const_set( :VERIFY_PEER, OpenSSL::SSL::VERIFY_NONE )

      @stack_hs = {}
      @nbinfos = {}
      @notebookinfo = Struct.new("NotebookInfo", :name, :stack, :defaultNotebook, :count , :tags )

      @authToken = authToken

      register_time = Arxutils::Dbutil::DbMgr.init( hs["db_dir"], hs["migrate_dir"] , hs["config_dir"], hs["dbconfig"] , hs["env"] , hs["log_fname"] , opts )

      @dbmgr = ::Enop::Dbutil::EnopMgr.new( register_time )
      puts "@dbmgr=#{@dbmgr}"
      
      
      evernoteHost = "www.evernote.com"
#      userStoreUrl = "https://#{evernoteHost}/edam/user" unless userStoreUrl
      userStoreUrl = "https://#{evernoteHost}/shard/s18/notestore"
#      userStoreUrl = 
      userStoreTransport = Thrift::HTTPClientTransport.new(userStoreUrl)
      userStoreProtocol = Thrift::BinaryProtocol.new(userStoreTransport)
      @userStore = Evernote::EDAM::UserStore::UserStore::Client.new(userStoreProtocol)
      # Invalid method name : 'checkVersion' が返されるので、とりあえずコメント化
=begin
      versionOK = @userStore.checkVersion("Evernote EDAMTest (Ruby)",
                                          Evernote::EDAM::UserStore::EDAM_VERSION_MAJOR,
                                          Evernote::EDAM::UserStore::EDAM_VERSION_MINOR)
      puts "Is my Evernote API version up to date?  #{versionOK}"
      exit(1) unless versionOK
=end
      set_output_dest( hs["output_dir"] , get_output_filename_base )
    end

    def set_output_dest( parent_dir , fname_base )
      if fname_base
		    outfname = File.join( parent_dir , fname_base )
        outfname_txt = outfname + ".txt"
        outfname_csv = outfname + ".csv"
        @output = File.open( outfname_txt , "w" , { :encoding => 'UTF-8' } )
        @output_csv = CSV.open( outfname_csv , "w" , { :encoding => 'UTF-8' } )
      else
        @output = STDOUT
      end
    end

    def get_output_filename_base
      Time.now.strftime("ennblist-%Y-%m-%d-%H-%M-%S")
    end

    def putsx( str )
      @output.puts( str )
    end

    def connect
      # Get the URL used to interact with the contents of the user's account
      # When your application authenticates using OAuth, the NoteStore URL will
      # be returned along with the auth token in the final OAuth request.
      # In that case, you don't need to make this call.
      #noteStoreUrl = userStore.getNoteStoreUrl(authToken)
      noteStoreUrl = "https://www.evernote.com/shard/s18/notestore"
      noteStoreTransport = Thrift::HTTPClientTransport.new(noteStoreUrl)
      noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
      @noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)
    end

    def get_notebooks
      begin
        notebooks = @noteStore.listNotebooks(@authToken)
      rescue Evernote::EDAM::Error::EDAMUserException => ex
        parameter = ex.parameter
        errorCode = ex.errorCode
        errorText = Evernote::EDAM::Error::EDAMErrorCode::VALUE_MAP[errorCode]

        puts "Authentication failed (parameter: #{parameter} errorCode: #{errorText})"

        exit(1)
      rescue => ex
        puts "@authToken=#{@authToken}"
        puts "Can't call listNotebooks"
        p ex
        exit
      end

      puts "Found #{notebooks.size} notebooks:"

      notebooks
    end

    def get_note_count( notebookguid , filter = nil )
      filter = Evernote::EDAM::NoteStore::NoteFilter.new unless filter
      filter.notebookGuid = notebookguid
      ret = nil
      begin
        ret = @noteStore.findNoteCounts(@authToken , filter , false )
      rescue => ex
        puts "Can't call findNoteCounts with #{notebookguid}"
      end

      ret
    end

    def get_url_from_notebook( name )
      @notebooks = get_notebooks unless @notebooks

      filter = Evernote::EDAM::NoteStore::NoteFilter.new

      notebook = @notebooks.find{ |x| x.name == name }
      filter.notebookGuid = notebook.guid
      ret = get_note_count( notebook.guid , filter )
      notebookCounts = 0
      if ret
        if ret.notebookCounts
          notebookCounts = ret.notebookCounts[notebook.guid]
        end
      end
      filter.ascending = false
      spec = Evernote::EDAM::NoteStore::NotesMetadataResultSpec.new
      spec.includeTitle = true
      spec.includeAttributes = true
      array_of_array = []
      count_unit = 100
      count = 0
      count.step(notebookCounts , count_unit) {|cnt|
        ourNoteList = @noteStore.findNotesMetadata(@authToken, filter, cnt, count_unit, spec)
        array_of_array << ourNoteList.notes.map{ |x| [x.title , x.attributes.sourceURL] }
      }
=begin
      while count < notebookCounts
        ourNoteList = @noteStore.findNotesMetadata(@authToken, filter, count, count_unit, spec)
        ourNoteList.notes.map{ |x| url_array << [x.title , .attributes.sourceURL] }
#        ourNoteList.notes.map{ |x| p x }
        count += count_unit
      end
=end
      array_of_array.flatten(1)
    end

    def list_notebooks
      # List all of the notebooks in the user's account

      @notebooks = get_notebooks unless @notebooks

      filter = Evernote::EDAM::NoteStore::NoteFilter.new

      memo = @notebooks.inject({:defaultNotebook => nil , :nbinfo => []}) do |memo , notebook|
        notebook_name = ( notebook.name == nil ? "" : notebook.name )
        stack_name = ( notebook.stack == nil ? "" : notebook.stack )
        ret = get_note_count( notebook.guid , filter )
        if ret
          if ret.notebookCounts
            notebookCounts = ret.notebookCounts[notebook.guid]
          else
            notebookCounts = 0
          end
          tagcount = 0
          if ret.tagCounts
            tagcount = ret.tagCounts.size
          end
          nbinfo = @notebookinfo.new( notebook_name , stack_name , notebook.defaultNotebook , notebookCounts , tagcount )
          # CSVファイルへ追加（自動的に出力）
          register_notebook( nbinfo.stack , nbinfo )
          # dbへの登録
          count = nbinfo.count
          count ||= 0
          @dbmgr.add(  nbinfo.stack , nbinfo.name , count , nbinfo.tags.size )

          #  p notebook
          memo[:defaultNotebook] = nbinfo if nbinfo.defaultNotebook
          memo[:nbinfo] << nbinfo
        end

        memo
      end

      @stack_hs.keys.sort.each do |k|
        # TXTファイルに出力
        putsx "#{k},#{@stack_hs[k]}"
      end

      pp memo[:defaultNotebook]
    end

    def register_notebook( stack , nbinfo )
      @stack_hs[stack] ||= []
      @stack_hs[stack] << nbinfo
      @nbinfos[nbinfo.name] = nbinfo

      @output_csv << [ stack , nbinfo.name , nbinfo.count ]
    end
  end
end

