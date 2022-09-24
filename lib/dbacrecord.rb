module Enop
module Dbutil
  class Count < ActiveRecord::Base
    has_many :invalidennblists
  end

  class Countdatetime < ActiveRecord::Base
  end

  class Evnb < ActiveRecord::Base
  end

  class Ennblist < ActiveRecord::Base
  end

  class Invalidennblist < ActiveRecord::Base
    belongs_to :ennblist, foreign_key: "org_id"
    belongs_to :count, foreign_key: ""
  end

  class Currentennblist < ActiveRecord::Base
    belongs_to :ennblist, foreign_key: "org_id"
  end

end
end
