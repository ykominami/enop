# -*- coding: utf-8 -*-
require 'active_record'
require 'forwardable'
require 'pp'

module Enop
  module Dbutil
    class Ennblist < ActiveRecord::Base
    end

    class Invalidennblist < ActiveRecord::Base
    end

    class Currentennblist < ActiveRecord::Base
      belongs_to :ennblist , foreign_key: 'org_id'
    end

    class Evnb < ActiveRecord::Base
    end

    class Countdatetime < ActiveRecord::Base
    end

    class EnopMgr
      extend Forwardable
      
      def initialize(register_time)
        @register_time = register_time
        @ct = Countdatetime.create( countdatetime: @register_time )
        @hs_by_notebook = {}
        @hs_by_id = {}
      end

      def add( stack , notebook, count, tag_count )
        ennblist = @hs_by_notebook[notebook]
        unless ennblist
          cur_ennblist = Currentennblist.where( notebook: notebook ).limit(1)
          if cur_ennblist.size == 0
            begin
              ennblist = Ennblist.create( stack: stack, notebook: notebook , count: count, tag_count: tag_count , start_datetime: @register_time )
              evnb = Evnb.create( time_id: @ct.id , ennb_id: ennblist.id )
            rescue => ex
              p ex.class
              p ex.message
              pp ex.backtrace

              ennblist = nil
              evnb = nil
            end
          else
            current_ennblist = cur_ennblist.first.ennblist
            hs = {:stack => stack, :count => count , :tag_count => tag_count }
            value_hs = hs.reduce({}){ |hsx,item|
              if current_ennblist[ item[0] ] != item[1]
                hsx[ item[0] ] = item[1]
              end
              hsx
            }
            if value_hs.size > 0
              if value_hs.all? { |item| item[1] != nil }
                current_ennblist.update(value_hs)
              end
            end
          end
        else
          # ignore this case.
        end
        
        if ennblist
          @hs_by_notebook[notebook] = ennblist
          @hs_by_id[ennblist.id] = ennblist
        end
        ennblist
      end
      
      def post_process( dir_id )
        h_ids = Currentennblist.pluck(:org_id)
        t_ids = @hs_by_id.keys
        ids = h_ids - t_ids
        if ids.size > 0
          ids.each do |idx| 
            Invalidennblist.create( org_id: idx , end_datetime: @register_time )
          end
        end
      end
    end
  end
end


