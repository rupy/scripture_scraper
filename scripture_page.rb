require 'nokogiri'

class ScripturePage

	def initialize
		# ロガーの初期化
		@log = Logger.new(STDERR)
		@log.level=Logger::DEBUG
	end

	def parse_contents(doc)
		book = doc/'book/@id'
		title = (doc/'title').inner_text
		@log.info("#{title} #{book}")

		infos = []
		infos
	end
end