module Enop
  module Dbutil
    class Count < ActiveRecord::Base
      has_many :invalidxennblists
    end

    class Countdatetime < ActiveRecord::Base
    end

    class Xevnb < ActiveRecord::Base
    end

    class Xennblist < ActiveRecord::Base
    end

    class Invalidxennblist < ActiveRecord::Base
      belongs_to :xennblist, foreign_key: "org_id"
      belongs_to :count, foreign_key: ""
    end

    class Currentxennblist < ActiveRecord::Base
      belongs_to :xennblist, foreign_key: "org_id"
    end
  end
end
