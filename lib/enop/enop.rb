# -*- coding: utf-8 -*-
require 'evernote-thrift'
require 'csv'
require 'pp'

require 'forwardable'
require 'dbutil_base'
require 'dbutil_enop'

module Enop
  class Enop
    extend Forwardable
    
    def_delegator( :@dbmgr , :add , :db_add)

    def initialize( authToken , kind, hs )

      @stack_hs = {}
      @nbinfos = {}
      @notebookinfo = Struct.new("NotebookInfo", :name, :stack, :defaultNotebook, :count , :tags )

      @authToken = authToken

      @dbmgr = Arxutils::Store.init(kind , hs ){ | register_time |
        Dbutil::DbMgr.new( register_time )
      }

      evernoteHost = "www.evernote.com"
      userStoreUrl = "https://#{evernoteHost}/edam/user"
      userStoreTransport = Thrift::HTTPClientTransport.new(userStoreUrl)
      userStoreProtocol = Thrift::BinaryProtocol.new(userStoreTransport)
      @userStore = Evernote::EDAM::UserStore::UserStore::Client.new(userStoreProtocol)

      versionOK = @userStore.checkVersion("Evernote EDAMTest (Ruby)",
                                          Evernote::EDAM::UserStore::EDAM_VERSION_MAJOR,
                                          Evernote::EDAM::UserStore::EDAM_VERSION_MINOR)
      puts "Is my Evernote API version up to date?  #{versionOK}"
      puts
      exit(1) unless versionOK

      set_output_dest( get_output_filename_base )
    end

    def set_output_dest( fname )
      if fname
        fname_txt = fname + ".txt"
        fname_csv = fname + ".csv"
        @output = File.open( fname_txt , "w" , { :encoding => 'UTF-8' } )
        @output_csv = CSV.open( fname_csv , "w" , { :encoding => 'UTF-8' } )
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

    def list_notebooks
      # List all of the notebooks in the user's account
      filter = Evernote::EDAM::NoteStore::NoteFilter.new

      begin
        notebooks = @noteStore.listNotebooks(@authToken)
      rescue => ex
        puts "Can't call listNotebooks"
        exit
      end

      puts "Found #{notebooks.size} notebooks:"
      memo = notebooks.inject({:defaultNotebook => nil , :nbinfo => []}) do |memo , notebook|
        notebook_name = ( notebook.name == nil ? "" : notebook.name )
        stack_name = ( notebook.stack == nil ? "" : notebook.stack )

        filter.notebookGuid = notebook.guid

        ret = nil
        begin
          ret = @noteStore.findNoteCounts(@authToken , filter , false )
        rescue => ex
          puts "Can't call findNoteCounts with #{notebook_name}"
        end

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
          db_add(  nbinfo.stack , nbinfo.name , nbinfo.count , nbinfo.tags.size )

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

