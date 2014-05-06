require 'logging'

File.open('app.log', 'w') {|file| file.truncate(0) }

LOGGER = Logging.logger['LOG']
LOGGER.add_appenders(
    Logging.appenders.stdout,
    Logging.appenders.file('app.log')
)
LOGGER.level = :debug

