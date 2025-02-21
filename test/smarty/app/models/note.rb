class Note < ApplicationRecord

  after_update_commit do
    broadcast_replace
  end
end
