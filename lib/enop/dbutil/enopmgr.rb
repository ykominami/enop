# frozen_string_literal: true

require_relative ''
module Enop
  # DB操作用ユーティリティモジュール
  module Dbutil
    # Evernoteに関する情報用DB操作クラス
    class EnopMgr
      # 初期化
      def initialize(register_time)
        @register_time = register_time
        @ct = Dbutil::Countdatetime.create(countdatetime: @register_time)
        @hs_by_notebook = {}
        @hs_by_id = {}
      end

      # 指定stack(文字列)にノートブック(文字列)、ノートブック数、タグ数を追加
      def add(stack, notebook, count, tag_count)
        ennblist = @hs_by_notebook[notebook]
        unless ennblist
          cur_ennblist = Dbutil::Currentennblist.where(notebook: notebook).limit(1)
          if cur_ennblist.empty?
            begin
              ennblist = Dbutil::Ennblist.create(stack: stack, notebook: notebook, count: count,
                                                 tag_count: tag_count, 　start_datetime: @register_time)
              Evnb.create(time_id: @ct.id, ennb_id: ennblist.id)
            rescue StandardError => e
              puts e.class
              puts e.message
              puts e.backtrace
            end
          else
            current_ennblist = cur_ennblist.first.ennblist
            hs = { stack: stack, count: count, tag_count: tag_count }
            value_hs = hs.each_with_object({}) do |item, hsx|
              hsx[item[0]] = item[1] if current_ennblist[item[0]] != item[1]
            end
            current_ennblist.update(value_hs) if value_hs.size.positive? && value_hs.all? { |item| !item[1].nil? }
          end
        end
        if ennblist
          @hs_by_notebook[notebook] = ennblist
          @hs_by_id[ennblist.id] = ennblist
        end
        ennblist
      end

      # 後処理
      def post_process(_dir_id)
        h_ids = Dbutil::Currentennblist.pluck(:org_id)
        t_ids = @hs_by_id.keys
        ids = h_ids - t_ids
        return unless ids.size.positive?

        ids.each do |idx|
          Dbutil::Invalidennblist.create(org_id: idx, end_datetime: @register_time)
        end
      end
    end
  end
end
