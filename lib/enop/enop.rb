# frozen_string_literal: true

require "evernote-thrift"
require "csv"
require "pp"
require "openssl"
require "forwardable"
require "json"
require "ykxutils"

# require "enop_sub"
module Enop
  # Evernote操作クラス
  class Enop
    # 初期化
    attr_reader :notebooks_hs, :notebooks_hs_backup, :notebooks_hs_notelist_backup

    NOTEBOOK_ITEM = Struct.new(:guid, :title, :notebook_guid, :notebook_name, :stack)
    NOTEBOOK_X = Struct.new(:name, :guid)

    def initialize(auth_token, note_store_url, hash)
      # SSL認証を行わないように変更
      OpenSSL::SSL.module_eval { remove_const(:VERIFY_PEER) }
      OpenSSL::SSL.const_set(:VERIFY_PEER, OpenSSL::SSL::VERIFY_NONE)

      @notebooks_hs = {}
      @notebooks = []

      @pstorex = Ykxutils::Pstorex.new(hash["output_dir"], "enop.dump")
      @pstorex.delete(:notebooks)
      @notebooks_hs_notelist_backup = @pstorex.fetch(:notebooks_hs_notelist, {})
      # hs = { notebooks_hs: @notebooks_hs, notelist: notelist }

      @notebooks_hs = @notebooks_hs_notelist_backup[:notebooks_hs]
      @notebooks_hs ||= {}
      @notelist = @notebooks_hs_notelist_backup[:notelist]
      @memox = @notebooks_hs_notelist_backup[:memox]

      # Evernoteのノートブックスタックの配列
      @stack_hs = {}
      # ノートブック情報の配列
      @nbinfos = {}
      # note_storeへのURL
      @note_store_url = note_store_url
      # 認証トークン
      @auth_token = auth_token

      # db_dir = hs["db_dir"]
      # config_dir = hs["config_dir"]
      env = hash["env"]
      dbconfig = hash["dbconfig"]
      config = Arxutils_Sqlite3::Config.new
      register_time = Arxutils_Sqlite3::Dbutil::Dbconnect.db_connect(config, dbconfig, env)
      # 保存用DBマネージャ
      @dbmgr = Dbutil::EnopMgr.new(register_time)

      set_output_dest(hash["output_dir"], output_filename_base)
    end

    # 出力先設定
    def set_output_dest(parent_dir, fname_base)
      if fname_base
        outfname = File.join(parent_dir, fname_base)
        outfname_txt = "#{outfname}.txt"
        outfname_csv = "#{outfname}.csv"
        # 出力先ファイル
        @output = File.open(outfname_txt, "w", encoding: "UTF-8")
        # 出力先ファイル(CSV形式)
        @output_csv = CSV.open(outfname_csv, "w", encoding: "UTF-8")
      else
        @output = $stdout
      end
    end

    # 出力ファイル名のベース部分作成
    def output_filename_base
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
      # noteStoreUrl = userStore.getNoteStoreUrl(authToken)
      # puts "@noteStoreUrl=#{@noteStoreUrl}"
      # puts "@noteStoreUrl.class=#{@noteStoreUrl.class}"
      # puts "@noteStoreUrl=#{@noteStoreUrl}"
      note_store_transport = Thrift::HTTPClientTransport.new(@note_store_url)
      note_store_protocol = Thrift::BinaryProtocol.new(note_store_transport)
      # Evernoteノートストア
      @note_store = Evernote::EDAM::NoteStore::NoteStore::Client.new(note_store_protocol)
    end

    # Evernoteノートブック取得
    def notebooks_from_remote
      notebooks_hs = {}
      begin
        notebooks = @note_store.listNotebooks(@authToken)
        notebooks_hs = Hash[*notebooks.map { |notebook| [notebook.guid, notebook] }.flatten]
      rescue Evernote::EDAM::Error::EDAMUserException => e
        puts e.parameter
        puts e.errorCode
        puts Evernote::EDAM::Error::EDAMErrorCode::VALUE_MAP[errorCode]
        exit(1)
      rescue StandardError => e
        puts e.message
        puts "@authToken=#{@authToken}"
        puts "Can't call listNotebooks"
        exit(2)
      end

      notebooks_hs
    end

    # 指定Evernoteノートブックが含むノート数取得
    def get_note_count(notebookguid, filter = nil)
      filter ||= Evernote::EDAM::NoteStore::NoteFilter.new
      filter.notebookGuid = notebookguid
      ret = nil
      begin
        ret = @note_store.findNoteCounts(@authToken, filter, false)
      rescue StandardError => e
        puts e.message
        puts "Can't call findNoteCounts with #{notebookguid}"
      end

      ret
    end

    # 文字列で指定したノートブックに含まれるノートのタイトルとソースのURLの配列取得
    def get_url_from_notebook(name)
      # Evernoteノートブック配列
      retrieve_notebooks

      filter = Evernote::EDAM::NoteStore::NoteFilter.new

      notebook = @notebooks_hs.values.find { |x| x.name == name }
      filter.notebookGuid = notebook.guid
      ret = get_note_count(notebook.guid, filter)
      notebook_counts = 0
      notebook_counts = ret.notebookCounts[notebook.guid] if ret&.notebookCounts
      filter.ascending = false
      spec = Evernote::EDAM::NoteStore::NotesMetadataResultSpec.new
      spec.includeTitle = true
      spec.includeAttributes = true
      array_of_array = []
      count_unit = 100
      count = 0
      count.step(notebook_counts, count_unit) do |cnt|
        our_note_list = @note_store.findNotesMetadata(@authToken, filter, cnt, count_unit, spec)
        array_of_array << our_note_list.notes.map { |x| [x.title, x.attributes.sourceURL] }
      end
      array_of_array.flatten(1)
    end

    def retrieve_notebooks_hs
      if @notebooks_hs.size.zero?
        @notebooks_hs = notebooks_from_remote
        # Evernoteノートブック配列
        @notebooks_hs_notelist_backup[:notebooks_hs] = @notebooks_hs

        @pstorex.store(:notebooks_hs_notelist, @notebooks_hs_notelist_backup)
      end
      @notebooks_hs
    end

    def retrieve_notebooks_hs_from_backup
      retrieve_notebooks_hs if @notebooks_hs.size.zero?
      @notebooks_hs
    end

    def get_all_notebooks_hs(from_backup: true)
      from_backup ? retrieve_notebooks_hs_from_backup : retrieve_notebooks_hs
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

    def get_notes_having_pdf_sub(filter, spec, head, unit, total = nil)
      # p "get_notes_having_pdf_sub 1"
      ary = []

      tail = head + unit - 1
      tail = total if total

      head.step(tail, unit) do |i|
        limit = i + unit - 1
        limit = tail if limit >= tail
        our_note_list = @note_store.findNotesMetadata(@authToken, filter, i, limit, spec)
        ary << our_note_list
      end
      ary
    end

    def notes_having_pdf_from_remote
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
      # spec.includeNotebookGuid = true

      head = 0
      unit = 500
      # tail = head + unit
      notelists = []
      ary = get_notes_having_pdf_sub(filter, spec, head, unit)
      next_head = head + unit
      # total =  our_note_list.total_notes
      total = ary[0].total_notes
      notelists << ary[0].notes
      ary = get_notes_having_pdf_sub(filter, spec, next_head, unit, total)
      notelists << ary.map(&:notes)
      notelist = notelists.flatten

      hs = { notebooks_hs: @notebooks_hs, notelist: notelist }
      output_in_json(hs)
      @pstorex.store(:notebooks_hs_notelist, hs)
      @notebooks_hs_notelist_backup = hs
    end

    def get_notes_having_pdf(from_backup: false)
      get_all_notebooks_hs(from_backup)

      notes_having_pdf_from_remote unless from_backup

      @notebooks_hs_notelist_backup[:notelist]
    end

    def make_filter(words)
      filter = Evernote::EDAM::NoteStore::NoteFilter.new
      filter.ascending = false
      filter.words = words
      filter
    end

    def list_note_having_pdf(from_backup: false)
      get_notes_having_pdf(from_backup)
      # pp "@notelist.size=#{@notelist.size}"
      # pp "===="
      stacks = @notelist.each_with_object({}) do |note, stack|
        # item = OpenStruct.new
        item = NOTEBOOK_ITEM.new
        item.guid = note.guid
        item.title = note.title
        item.notebook_guid = note.notebookGuid
        item.notebook_name = @notebooks_hs[note.notebookGuid].name
        item.stack = @notebooks_hs[note.notebookGuid].stack
        item.stack = "" unless item.stack
        stack[item.stack] ||= {}
        stack[item.stack][item.notebook_name] ||= []
        stack[item.stack][item.notebook_name] << item
      end
      stacks.keys.sort.map do |name|
        # puts name
        stacks[name].keys.sort.map do |x|
          # puts " #{x}"
          # puts stacks[name][x].map { |note|
          #  "  #{note.title} #{note.guid}"
          # }
        end
      end
    end

    def make_filter_with_notebook_guid(notebook_guid)
      filter = make_filter("resource:application/pdf")
      filter.notebookGuid = notebook_guid
      filter
    end

    def get_stack_notebooks(from_backup: true)
      notebooks_hs = get_all_notebooks_hs(from_backup: from_backup)
      notebooks_hs.keys.each_with_object({}) do |guid, memo|
        nb = notebooks_hs[guid]
        stack = nb.stack
        stack ||= ""
        memo[stack] ||= {}
        # item = OpenStruct.new
        item = NOTEBOOK_X.new
        item.name = nb.name
        item.name = "" unless item.name
        item.guid = nb.guid
        memo[stack][nb.name] = item
      end
    end

    def list_notebooks(from_backup: true)
      memox = get_stack_notebooks(from_backup: from_backup)
      memox.keys.sort.map do |slack|
        # puts "slack=#{slack}"
        memox[slack].keys.sort.map do |nb_name|
          memox[slack][nb_name]
          # puts " #{nb_name} #{item.guid}"
        end
      end
    end

    def get_note_having_pdf_by_notebook(guid, spec)
      filter = make_filter_with_notebook_guid(guid)
      ary = []
      head = 0
      unit = 100
      i = head
      our_note_list = @note_store.findNotesMetadata(@authToken, filter, i, unit, spec)
      ary << our_note_list
      total_notes = our_note_list.totalNotes
      i += our_note_list.notes.size
      while i < total_notes
        # puts "#{i}/#{total_notes}"
        our_note_list = @note_store.findNotesMetadata(@authToken, filter, i, unit, spec)
        ary << our_note_list
        break if our_note_list.notes.size.zero?

        i += our_note_list.notes.size
      end
      notelist = ary.map(&:notes).flatten
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
      # spec.includeNotebookGuid = true
      spec
    end

    def list_notebooks_having_pdf(from_backup)
      spec = make_spec
      memox = get_stack_notebooks(from_backup)
      stack_list = []
      stack_list << %w[8-sci]
      # stack_list << %W(1-security)
      # stack_list << %W(1-dev-web-design)
      stack_list << %w[1-dev-lang]
      # stack_list << %W(1-dev-web)
      # stack_list << %W(1-dev-tech)
      # stack_list << %W(1-dev-p)
      # stack_list << %W(1-dev-env)
      # stack_list << %W(0-PRJ)
      stack_list.flatten.map do |stack|
        memox[stack].keys.sort.map do |x|
          guid = memox[stack][x].guid
          # puts "#{x} #{guid}"
          size = get_note_having_pdf_by_notebook(guid, spec)
          memox[stack][x].size_of_notes = size
          # pp size
        end
      end
      @notebooks_hs_notelist_backup[:memox] = memox
      @pstorex.store(:notebooks_hs_notelist, @notebooks_hs_notelist_backup)
    end

    def latest_100_notes(from_backup: false)
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
      # spec.includeNotebookGuid = true

      head = 0
      unit = 10
      tail = head + unit
      our_note_list = @note_store.findNotesMetadata(@authToken, filter, head, tail, spec)
      hs = { notebooks_hs: notebooks_hs, notelist: our_note_list }
      output_in_json(hs)
      @pstorex.store(:notebooks_hs_notelist, hs)
    end
  end
end
