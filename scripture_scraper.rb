require 'logger'
require 'yaml'
require './web_fetcher'
require './scripture_page'
require './info_writer'

class ScriptureScraper

	TITLES = ["bom", 'd_c', 'pog', 'old', 'new']
	def initialize

		# ロガーの初期化
		@log = Logger.new(STDERR)
		@log.level=Logger::DEBUG
		@log.debug('Initilizing instance')

		@config = YAML.load_file('config/config.yml')

		@web_fetcher = WebFetcher.new

	end

	def scrape_scriptures(lang = 'eng', overwrite_flag = false)
		@log.info("start parsing")

		@web_fetcher.fetch_and_store_web_pages lang, overwrite_flag

		all_infos = []
		# titleに対して
		TITLES.each_with_index do |title, title_id|

			# title_id += 1

			all_infos_in_book = []

			if @web_fetcher.undownloadable? lang, title
				@log.info("#{lang}, #{title} is not downloadable. skip.")
				next
			end

			# bookに対して
			names = @web_fetcher.get_names title_id
			names.each_with_index do |(book_name, chapter_name), page_id|

				@log.info("*** #{book_name} #{page_id} ***")
				web_data = @web_fetcher.read_web_data lang, title_id, page_id
				if web_data.nil?
					puts '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@'
					next
				end
				# next if page_id < 78

				scripture_page = ScripturePage.new lang, title, book_name
				doc = Nokogiri::HTML.parse(web_data){ |config| config.noblanks }
				infos = scripture_page.parse_contents doc
				# all_infos_in_book.push infos
				all_infos_in_book.push({title: title, book: book_name, chapter: chapter_name, infos: infos})

				# exit(0)


				if title == 'bom' && book_name == 'introduction' && lang =='jpn'

					['three', 'eight', 'js'].each do |book_name2|

						scripture_page = ScripturePage.new lang, title, book_name2
						doc = Nokogiri::HTML.parse(web_data)
						infos = scripture_page.parse_contents doc
						# all_infos_in_book.push infos
						all_infos_in_book.push({title: title, book: book_name2, chapter: chapter_name, infos: infos})

					end
				end
			end
			all_infos.push all_infos_in_book
		end
		iw = InfoWriter.new lang
		iw.write_infos_to_csv(all_infos)

	end

end