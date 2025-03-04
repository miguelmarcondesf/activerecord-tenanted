module ApplicationCable
  class Connection < ActionCable::Connection::Base
    tenanted_connection
  end
end
