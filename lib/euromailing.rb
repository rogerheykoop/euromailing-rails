require "euromailing/version"
require "euromailing/errors"
require "euromailing/configuration"
require "euromailing/client"
require "euromailing/delivery_method"

# Syncable/SyncJob need ActiveSupport/ActiveJob; inside a Rails app the
# Railtie requires them at the right moment via load hooks. Outside Rails
# (plain Ruby, tests) they load here when the dependencies are present.
require "euromailing/syncable" if defined?(ActiveSupport)
require "euromailing/sync_job" if defined?(ActiveJob)

require "euromailing/railtie" if defined?(Rails::Railtie)
