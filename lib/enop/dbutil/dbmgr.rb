# -*- coding: utf-8 -*-
require 'enop/dbutil/enopmgr'
require 'forwardable'
require 'pp'

module Enop
  module Dbutil
    class DbMgr
      extend Forwardable
      
      def_delegator( :@ennblistmgr , :add, :add)
      
      def initialize( register_time )
        @ennblistmgr = EnopMgr.new( register_time )
      end
    end
  end
end

