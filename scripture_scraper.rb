require 'logger'
require 'yaml'
require './web_fetcher'

class ScriptureScraper

	TITLES = ["bom", 'd_c', 'pog', 'old', 'new']
	def initialize

		# ロガーの初期化
		@log = Logger.new(STDERR)
		@log.level=Logger::DEBUG
		@log.debug('Initilizing instance')

		@config = YAML.load_file('config/config.yml')

		@web_fetcher = WebFetcher.new @config

	end

	def scrape_scriptures(lang = 'eng', overwrite_flag = false)
		@log.info("start parsing")

		@web_fetcher.fetch_and_store_web_pages lang, overwrite_flag

	end

end