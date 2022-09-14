# -*- coding: utf-8 -*-
require "evernote-thrift"
require "csv"
require "pp"
require "openssl"
require "forwardable"
require "pstore"
require "json"
#require "enop_sub"
module Enop
  # Evernote操作クラス
  class Enop
    # 初期化
    attr_reader :notebooks_hs, :notebooks_hs_backup, :notebooks_hs_notelist_backup

    def initialize(authToken, hs, noteStoreUrl)
      # SSL認証を行わないように変更
      OpenSSL::SSL.module_eval { remove_const(:VERIFY_PEER) }
      OpenSSL::SSL.const_set(:VERIFY_PEER, OpenSSL::SSL::VERIFY_NONE)

      @store_db = PStore.new(Pathname.new(hs["output_dir"]) + "enop.dump")
      @notebooks_hs = {}
      @notebooks = []
      @store_db.transaction do
        @store_db.delete(:notebooks)
        @notebooks_hs_notelist_backup = @store_db.fetch(:notebooks_hs_notelist, {})
      end
      #hs = { notebooks_hs: @notebooks_hs, notelist: notelist }

      @notebooks_hs = @notebooks_hs_notelist_backup[:notebooks_hs]
      @notebooks_hs = {} unless @notebooks_hs
      @notelist = @notebooks_hs_notelist_backup[:notelist]
      @memox = @notebooks_hs_notelist_backup[:memox]

      # Evernoteのノートブックスタックの配列
      @stack_hs = {}
      # ノートブック情報の配列
      @nbinfos = {}
      # ノートブック情報のStruct
      @notebookinfo = Struct.new("NotebookInfo", :name, :stack, :defaultNotebook, :count, :tags)

      # noteStoreへのURL
      @noteStoreUrl = noteStoreUrl
      # 認証トークン
      @authToken = authToken

      db_dir = hs["db_dir"]
      config_dir = hs["config_dir"]
      env = hs["env"]
      dbconfig = hs["dbconfig"]

      dbconfig_path = Arxutils_Sqlite3::Util.make_dbconfig_path(config_dir, dbconfig)
      log_path = Arxutils_Sqlite3::Util.make_log_path(db_dir, dbconfig)
      dbconnect = Arxutils_Sqlite3::Dbutil::Dbconnect.new(
        dbconfig_path,
        env,
        log_path
      )
      register_time = dbconnect.connect

      # 保存用DBマネージャ
      @dbmgr = ::Enop::Dbutil::EnopMgr.new(register_time)
      puts "@dbmgr=#{@dbmgr}"

      # Invalid method name : 'checkVersion' が返されるので、とりあえずコメント化
      set_output_dest(hs["output_dir"], get_output_filename_base)
    end

    # 出力先設定
    def set_output_dest(parent_dir, fname_base)
      if fname_base
        outfname = File.join(parent_dir, fname_base)
        outfname_txt = outfname + ".txt"
        outfname_csv = outfname + ".csv"
        # 出力先ファイル
        @output = File.open(outfname_txt, "w", { :encoding => "UTF-8" })
        # 出力先ファイル(CSV形式)
        @output_csv = CSV.open(outfname_csv, "w", { :encoding => "UTF-8" })
      else
        @output = STDOUT
      end
    end

    # 出力ファイル名のベース部分作成
    def get_output_filename_base
      Time.now.strftime("ennblist-%Y-%m-%d-%H-%M-%S")
    end

    # 出力先に文字列出力
    def putsx(str)
      @output.puts(str)
    end

    # Evernoteへ接続
    def connect
      # Get the URL used to interact with the contents of the user's account
      # When your application authenticates using OAuth, the NoteStore URL will
      # be returned along with the auth token in the final OAuth request.
      # In that case, you don't need to make this call.
      #noteStoreUrl = userStore.getNoteStoreUrl(authToken)
      noteStoreTransport = Thrift::HTTPClientTransport.new(@noteStoreUrl)
      noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
      # Evernoteノートストア
      @noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)
    end

    # Evernoteノートブック取得
    def get_notebooks_from_remote
      notebooks_hs = {}
      begin
        notebooks = @noteStore.listNotebooks(@authToken)
        notebooks_hs = Hash[*notebooks.map { |notebook| [notebook.guid, notebook] }.flatten]
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
        exit(2)
      end

      #puts "Found #{notebooks.size} notebooks:"
      #puts "get_notebooks_from_remote notebooks_hs=#{notebooks_hs}"
      notebooks_hs
    end

    # 指定Evernoteノートブックが含むノート数取得
    def get_note_count(notebookguid, filter = nil)
      filter = Evernote::EDAM::NoteStore::NoteFilter.new unless filter
      filter.notebookGuid = notebookguid
      ret = nil
      begin
        ret = @noteStore.findNoteCounts(@authToken, filter, false)
      rescue => ex
        puts "Can't call findNoteCounts with #{notebookguid}"
      end

      ret
    end

    # 文字列で指定したノートブックに含まれるノートのタイトルとソースのURLの配列取得
    def get_url_from_notebook(name)
      # Evernoteノートブック配列
      get_notebooks

      filter = Evernote::EDAM::NoteStore::NoteFilter.new

      notebook = @notebooks_hs.values.find { |x| x.name == name }
      filter.notebookGuid = notebook.guid
      ret = get_note_count(notebook.guid, filter)
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
      count.step(notebookCounts, count_unit) { |cnt|
        ourNoteList = @noteStore.findNotesMetadata(@authToken, filter, cnt, count_unit, spec)
        array_of_array << ourNoteList.notes.map { |x| [x.title, x.attributes.sourceURL] }
      }
      array_of_array.flatten(1)
    end

    def get_notebooks_hs
      if @notebooks_hs.size == 0
        @notebooks_hs = get_notebooks_from_remote
        # Evernoteノートブック配列
        @notebooks_hs_notelist_backup[:notebooks_hs] = @notebooks_hs

        @store_db.transaction do
          @store_db[:notebooks_hs_notelist] = @notebooks_hs_notelist_backup
        end
      end
      @notebooks_hs
    end

    def get_notebooks_hs_from_backup
      if @notebooks_hs.size == 0

        get_notebooks_hs
      end
      @notebooks_hs
    end

    def get_all_notebooks_hs(from_backup = false)
      from_backup ? get_notebooks_hs_from_backup : get_notebooks_hs
    end

    def output_in_json(obj)
      putsx(JSON.pretty_generate(obj))
    end

    # スタックにノートブックに関する情報を登録
    def register_notebook(stack, nbinfo)
      @stack_hs[stack] ||= []
      @stack_hs[stack] << nbinfo
      @nbinfos[nbinfo.name] = nbinfo

      @output_csv << [stack, nbinfo.name, nbinfo.count]
    end

    def get_notes_having_pdf_sub_0(filter, spec, head, unit, total = nil)
      ary = []

      tail = head + unit - 1
      tail = total if total

      head.step(tail, unit) { |i|
        #puts "i=#{i}"
        limit = i + unit - 1
        limit = tail if limit >= tail
        puts "i=#{i} limit=#{limit}"
        ourNoteList = @noteStore.findNotesMetadata(@authToken, filter, i, limit, spec)
        #ourNoteList = OpenStruct.new
        #ourNoteList.totalNotes = 1000
        #ourNoteList.notes = [ {}, {} ]
        puts "ourNoteList.totalNotes=#{ourNoteList.totalNotes}"
        puts "ourNoteList.notes.size=#{ourNoteList.notes.size}"
        ary << ourNoteList
      }
      ary
    end

    def get_notes_having_pdf_sub(filter, spec, head, unit, total = nil)
      p "get_notes_having_pdf_sub 1"
      ary = []

      tail = head + unit - 1
      tail = total if total

      head.step(tail, unit) { |i|
        #puts "i=#{i}"
        limit = i + unit - 1
        limit = tail if limit >= tail
        puts "i=#{i} limit=#{limit}"
        ourNoteList = @noteStore.findNotesMetadata(@authToken, filter, i, limit, spec)
        #ourNoteList = OpenStruct.new
        #ourNoteList.totalNotes = 1000
        #ourNoteList.notes = [ {}, {} ]
        puts "ourNoteList.totalNotes=#{ourNoteList.totalNotes}"
        puts "ourNoteList.notes.size=#{ourNoteList.notes.size}"
        ary << ourNoteList
      }
      ary
    end

    def get_notes_having_pdf_from_remote
      puts " get_notes_having_pdf_from_remote 0"
      filter = Evernote::EDAM::NoteStore::NoteFilter.new
      filter.ascending = false
      filter.words = "resource:application/pdf"

      spec = Evernote::EDAM::NoteStore::NotesMetadataResultSpec.new
      spec.includeTitle = true
      spec.includeCreated = true
      spec.includeUpdated = true
      spec.includeDeleted = true
      spec.includeUpdateSequenceNum = true
      spec.includeNotebookGuid = true
      spec.includeTagGuids = true
      spec.includeAttributes = true
      #spec.includeNotebookGuid = true

      head = 0
      unit = 500
      tail = head + unit
      notelists = []
      # ourNoteList = @noteStore.findNotesMetadata(@authToken, filter, head, tail, spec)
      # ourNoteList = get_notes_having_pdf_sub(filter, spec, head, unit)
      ary = get_notes_having_pdf_sub(filter, spec, head, unit)
      next_head = head + unit
      # total = ourNoteList.totalNotes
      total = ary[0].totalNotes
      p "total=#{total}"
      notelists << ary[0].notes
      # ourNoteList = get_notes_having_pdf_sub(filter, spec, next_head, unit, total)
      ary = get_notes_having_pdf_sub(filter, spec, next_head, unit, total)
      notelists << ary.map { |x| x.notes }
      notelist = notelists.flatten
      p notelist.size

      hs = { notebooks_hs: @notebooks_hs, notelist: notelist }
      output_in_json(hs)
      @store_db.transaction do
        @store_db[:notebooks_hs_notelist] = hs
      end
      @notebooks_hs_notelist_backup = hs
    end

    def get_notes_having_pdf(from_backup = false)
      get_all_notebooks_hs(from_backup)

      get_notes_having_pdf_from_remote unless from_backup

      @notebooks_hs_notelist_backup[:notelist]
    end

    def make_filter(words)
      filter = Evernote::EDAM::NoteStore::NoteFilter.new
      filter.ascending = false
      filter.words = words
      filter
    end

    def list_note_having_pdf(from_backup = false)
      get_notes_having_pdf(from_backup)
      filter = make_filter("resource:application/pdf")
      pp "@notelist.size=#{@notelist.size}"
      pp "===="
      stacks = @notelist.reduce({}) { |stack, note|
        item = OpenStruct.new
        item.guid = note.guid
        item.title = note.title
        item.notebook_guid = note.notebookGuid
        item.notebook_name = @notebooks_hs[note.notebookGuid].name
        item.stack = @notebooks_hs[note.notebookGuid].stack
        item.stack = "" unless item.stack
        #pp @notebooks_hs[note.notebookGuid]
        #exit
        stack[item.stack] ||= {}
        stack[item.stack][item.notebook_name] ||= []
        stack[item.stack][item.notebook_name] << item
        stack
      }
      stacks.keys.sort.map { |name|
        puts name
        stacks[name].keys.sort.map { |x|
           puts " #{x}"
           puts stacks[name][x].map { |note|
             "  #{note.title} #{note.guid}"
           }
        }
      }
    end


    def list_note_having_pdf_0(from_backup = false)
      get_notes_having_pdf(from_backup)
      filter = make_filter("resource:application/pdf")
      pp "@notelist.size=#{@notelist.size}"
      pp "===="
      stacks = @notelist.reduce({}) { |stack, note|
        item = OpenStruct.new
        item.guid = note.guid
        item.title = note.title
        item.notebook_guid = note.notebookGuid
        item.notebook_name = @notebooks_hs[note.notebookGuid].name
        item.stack = @notebooks_hs[note.notebookGuid].stack
        item.stack = "" unless item.stack
        #pp @notebooks_hs[note.notebookGuid]
        #exit
        stack[item.stack] ||= {}
        stack[item.stack][item.notebook_name] ||= []
        stack[item.stack][item.notebook_name] << item
        stack
      }
      stacks.keys.sort.map { |name|
        puts name
        stacks[name].keys.sort.map { |x|
           puts " #{x}"
           puts stacks[name][x].map { |note|
             "  #{note.title} #{note.guid}"
           }
        }
      }
    end

    def make_filter_with_notebook_guid(notebook_guid)
      filter = make_filter("resource:application/pdf")
      filter.notebookGuid = notebook_guid
      filter
    end

    def get_stack_notebooks(from_backup)
      notebooks_hs = get_all_notebooks_hs(from_backup)
      memox = notebooks_hs.keys.reduce({}){ |memo, guid|
        nb = notebooks_hs[guid]
        stack = nb.stack
        stack = "" unless stack
        memo[stack] ||= {}
        item = OpenStruct.new
        item.name = nb.name
        item.name = "" unless item.name
        item.guid = nb.guid
        memo[stack][nb.name] = item
        memo
      }
    end

    def list_notebooks(from_backup)
      p "========================="
      memox = get_stack_notebooks(from_backup)
      memox.keys.sort.map { |slack|
        puts "slack=#{slack}"
        memox[slack].keys.sort.map { |nb_name|
          item = memox[slack][nb_name]
          puts " #{nb_name} #{item.guid}"
        }
      }
    end

    def get_note_having_pdf_by_notebook(guid, spec)
      filter = make_filter_with_notebook_guid(guid)
      ary = []
      head = 0
      unit = 100
      notelists = []
      i = head
      ourNoteList = @noteStore.findNotesMetadata(@authToken, filter, i, unit, spec)
      ary << ourNoteList
      totalNotes = ourNoteList.totalNotes
      i = i + ourNoteList.notes.size
      while i < totalNotes
        puts "#{i}/#{totalNotes}"
        ourNoteList = @noteStore.findNotesMetadata(@authToken, filter, i, unit, spec)
        ary <<  ourNoteList
        break if ourNoteList.notes.size == 0 
        i = i + ourNoteList.notes.size
      end
      notelist = ary.map{ |x| x.notes }.flatten
      notelist.size
    end

    def make_spec
      spec = Evernote::EDAM::NoteStore::NotesMetadataResultSpec.new
      spec.includeTitle = true
      spec.includeCreated = true
      spec.includeUpdated = true
      spec.includeDeleted = true
      spec.includeUpdateSequenceNum = true
      spec.includeNotebookGuid = true
      spec.includeTagGuids = true
      spec.includeAttributes = true
      #spec.includeNotebookGuid = true
      spec
    end

    def list_notebooks_having_pdf(from_backup)
      spec = make_spec
      memox = get_stack_notebooks(from_backup)
      stack_list = []
      stack_list << %W(8-sci)
      #stack_list << %W(1-security)
      #stack_list << %W(1-dev-web-design)
      stack_list << %W(1-dev-lang)
      #stack_list << %W(1-dev-web)
      #stack_list << %W(1-dev-tech)
      #stack_list << %W(1-dev-p)
      #stack_list << %W(1-dev-env)
      #stack_list << %W(0-PRJ)
      stack_list.flatten.map{ |stack|
        memox[stack].keys.sort.map{ |x| 
          guid = memox[stack][x].guid
          puts "#{x} #{guid}"
          size = get_note_having_pdf_by_notebook(guid, spec)
          memox[stack][x].size_of_notes = size
          pp size
        }
      }
      @notebooks_hs_notelist_backup[:memox] = memox
      @store_db.transaction do
        @store_db[:notebooks_hs_notelist] = @notebooks_hs_notelist_backup
      end
    end

    def getLatest100Notes(from_backup = false)
      notebooks_hs = get_all_notebooks_hs(from_backup)

      filter = Evernote::EDAM::NoteStore::NoteFilter.new
      filter.ascending = false
      filter.words = "resource:application/pdf"
      spec = Evernote::EDAM::NoteStore::NotesMetadataResultSpec.new
      spec.includeTitle = true
      spec.includeCreated = true
      spec.includeUpdated = true
      spec.includeDeleted = true
      spec.includeUpdateSequenceNum = true
      spec.includeNotebookGuid = true
      spec.includeTagGuids = true
      spec.includeAttributes = true
      #spec.includeNotebookGuid = true

      head = 0
      unit = 10
      tail = head + unit
      ourNoteList = @noteStore.findNotesMetadata(@authToken, filter, head, tail, spec)
      hs = { notebooks_hs: notebooks_hs, notelist: ourNoteList }
      output_in_json(hs)
      @store_db.transaction do
        @store_db[:notebooks_hs_notelist] = hs
      end
    end
  end
end
