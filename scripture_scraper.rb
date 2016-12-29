require 'logger'
require 'yaml'

class ScriptureScraper

	def initialize

		# ロガーの初期化
		@log = Logger.new(STDERR)
		@log.level=Logger::DEBUG
		@log.debug('Initilizing instance')

		@config = YAML.load_file('config/config.yml')
	end

	def scrape_scriptures(overwrite_flag = false)
		@log.info("start parsing")

	end

end