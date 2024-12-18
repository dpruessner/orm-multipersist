require 'orm-multipersist'
require 'orm-multipersist/entity'
require 'orm-multipersist/sqlite'

module Rails
  class Application
    include ActiveSupport::LazyLoadHooks

    def self.root
      app_root
    end

    def config
      nil
    end
  end

  def self.application
    @application ||= Application.new
  end
end
