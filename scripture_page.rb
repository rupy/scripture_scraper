require 'nokogiri'
require './parse_base'
require './verse_processor'
require './chronicle_processor'

class ScripturePage < ParseBase

	include JapaneseIntroductionProcessor
	include VerseProcessor
	include ChronicleProcessor

	STATE_NORMAL = 0
	STATE_BOOK_CHANGE = 1

	VERSE_TYPE_CHAPTER_TITLE = "chapter_title"

	def initialize(lang, title, book)

		@lang = lang
		@title = title
		@book = book
		@state = STATE_NORMAL

		super()
	end

	def parse_verses(node, type='verses')
		verse_infos = []
		node.children.each do |verse_node|
			next if empty_text_node? verse_node

			if verse_node.name == "p"
				if type == 'verses'
					@log.debug('verse')
					info = parse_verse(verse_node) # p要素
				else
					# TODO: ここに来る要素って何？要確認。
					@log.debug(type)
					info = parse_verse(verse_node, type) # p要素
				end
				verse_infos.push(info) unless info.nil?
			elsif verse_node.name == "div" && verse_node['class'] == 'closing'
				@log.debug("closing")
				info = parse_verse(verse_node, 'closing') # div要素
				verse_infos.push(info) unless info.nil?
			elsif verse_node.name == "div" && (verse_node['class'] == 'signature' || verse_node['class'] == 'office')
				@log.debug(verse_node['class'])
				eid = verse_node['eid'] # これは何？
				words = verse_node['words'] # これは何？
				info = parse_verse(verse_node, 'signature') # div要素
				verse_infos.push(info) unless info.nil?
			elsif verse_node.name == "div" && verse_node['class'] == 'figure'
				if check_and_get_child(verse_node).name == 'ol' && check_and_get_child(verse_node)['class'] == 'number' # モルモン書の概要で登場, アブラハム書の模写にも
					check_and_get_child(verse_node).children.each do |li_node|
						next if empty_text_node? li_node
						eid = li_node['eid'] # これは何？
						words = li_node['words'] # これは何？
						@log.debug("figure_number")
						info = parse_verse(li_node, 'figure_number')
						verse_infos.push(info) unless info.nil?
					end
				elsif check_and_get_child(verse_node).name == 'ul' && check_and_get_child(verse_node)['class'] == 'noMarker' # D&Cの前書きで登場
					@log.debug("figure_nomarker")
					check_and_get_child(verse_node).children.each do |li_node|
						next if empty_text_node? li_node
						if li_node.name == 'div' && li_node['class'] == 'preamble'
							@log.debug("preamble")
							info = parse_verse(li_node, 'preamble')
						elsif li_node.name == 'li'
							p_node = (li_node/"p[1]")[0] # pノードの前後に空のテキストノードが入っている
							raise "Unknown node '#{p_node.to_html}' found" unless p_node.name == 'p'
							@log.debug("figure_nomerker")
							info = parse_verse(p_node, 'figure_nomerker')
						else
							raise "Unknown node '#{li_node.to_html}' found"
						end
						verse_infos.push(info) unless info.nil?
					end
				end
			elsif verse_node.name == "div" && verse_node['class'] == 'topic' # D&Cの前書きで登場
				verse_node.children.each do |topic_node|
					next if empty_text_node? topic_node
					if topic_node.name == 'h2' && @lang == 'jpn' && @book == 'introduction' # 日本語序文で３人の証人など複数を含んでいる部分の処理
						@state = STATE_BOOK_CHANGE
						@log.info("start changing book")
						return verse_infos
					elsif topic_node.name == 'h2'
						@log.debug("topic_header")
						info = parse_verse(topic_node, 'topic_header')
					elsif topic_node.name == 'p'
						@log.debug("topic")
						info = parse_verse(topic_node, 'topic')
					elsif topic_node['class'] == 'summary' # ジョセフ・スミス歴史で登場
						@log.debug("topic_summary")
						if check_and_get_child(topic_node).name == 'p'
							info = parse_verse(check_and_get_child(topic_node), 'topic_summary')
						else
							raise "Unknown node '#{check_and_get_child(topic_node).name}' found"
						end
					elsif topic_node['class'] == 'wideEllipse' # ジョセフ・スミス歴史で登場	
						@log.debug("wideEllipse")
						info = parse_verse(topic_node, 'topic')
					else
						raise "Unknown node '#{topic_node.to_html}' found"
					end
					verse_infos.push(info) unless info.nil?
				end
			elsif verse_node.name == "div" && verse_node['class'] == 'openingBlock' # 公式の宣言で登場	
				verse_node.children.each do |div_node|
					if div_node.name == 'text'
						next
					elsif div_node.name == 'div' && div_node['class'] == 'salutation'
						@log.debug("salutation")
						info = parse_verse(div_node, 'salutation')
						verse_infos.push(info) unless info.nil?
					elsif div_node.name == 'div' && div_node['class'] == 'date'
						@log.debug("date")
						info = parse_verse(div_node, 'date')
						verse_infos.push(info) unless info.nil?
					elsif div_node.name == 'div' && div_node['class'] == 'addressee'
						@log.debug("addressee")
						info = parse_verse(div_node, 'addressee')
						verse_infos.push(info) unless info.nil?
					elsif div_node.name == 'p' && div_node['class'] == ''
						@log.debug("opening_verse")
						info = parse_verse(div_node, "opening_verse")
						verse_infos.push(info) unless info.nil?
					else
						puts div_node.name
						puts div_node['class']
						raise "Unknown node '#{div_node.to_html}' found"
					end
				end
			elsif verse_node.name == "div" && verse_node['class'] == 'date' # 公式の宣言で登場	
				@log.debug("date")
				info = parse_verse(verse_node, 'date')
				verse_infos.push(info) unless info.nil?
			elsif verse_node.name == "ol" && verse_node['class'] == 'symbol' # ジョセフ・スミス歴史で登場
				li_node = check_and_get_child(verse_node)
				div_node = check_and_get_child(li_node)
				div_node.children.each do |symbol_node|
					if symbol_node.name == 'span' && symbol_node['class'] == 'label'
						@log.debug("label found ... skip")
						next
					else
						@log.debug("symbol")
						info = parse_verse(symbol_node, 'symbol')
						verse_infos.push(info) unless info.nil?
					end
				end
			elsif verse_node.name == "div" && verse_node['class'] == 'blockQuote' # 欽定訳のタイトルページで登場	
				@log.debug("blockQuote")
				info = parse_verse(verse_node, 'blockQuote')
				verse_infos.push(info) unless info.nil?
			elsif verse_node.name == "span" && verse_node['class'] == 'center' # 日本語のジョセフ・スミスの証で登場	
				@log.debug("center")
				info = parse_verse(verse_node, 'center')
				verse_infos.push(info) unless info.nil?
			else
				raise "Unknown node '#{verse_node.to_html}' found"
			end

		end
		verse_infos
	end

	def parse_contents(doc)

		# 聖文の部分を取得
		content = doc/"div[@id='content']//div[@id='primary']"

		# 日本語の３人の証人の証
		if @title == 'bom' && BOOK_LIST_NOT_IN_JPN.include?(@book) && @lang == 'jpn'

			all_infos = japanese_introduction_process(content, @book)

			return all_infos

		end

		# タイトルの部分を取得
		detail = doc/"div[@id='details']//h1"
		title_info = parse_verse(detail[0], 'title')
		title_name = title_info[:text]
		@log.info("@@ #{title_name} @@")

		all_infos = [title_info]
		content.children.each do |node|

			line = nil

			# textノードを飛ばす
			next if empty_text_node? node

			next if node.name == "div" && node["id"] == "media"
			next if node.name == "div" && node["id"] == "audio-player"
			next if node.name == "div" && node["class"] == "audio-player" # 日本語1Ne1で登場
			next if node.name == "ul" && node["class"].start_with?("prev-next")

			if @book == 'chron-order'
				infos = parse_chr node
				all_infos.push *infos

			elsif node.name == "h2"
				@log.info("chapter_title")
				# puts node.inner_html
				info = build_info(type: VERSE_TYPE_CHAPTER_TITLE, text: node.inner_html)
				all_infos.push info

			elsif ["subtitle", "intro", "studyIntro", "closing"].include?(node["class"])
				# stydyIntroはモーサヤ9章で初登場
				@log.info(node["class"])
				preface_nodes = node/"div[@class='preface']"
				comprising_nodes = node/"div[@class='comprising']"
				if !preface_nodes.empty?
					# モーサヤ９章でなんかintroのなかにprefaceが入ってるところがあるため
					info = parse_verse(preface_nodes[0], node["class"])
				elsif !comprising_nodes.empty?
					# モーサヤ９章でなんかstudyIntroのなかにcomprisingが入ってるところがあるため
					info = parse_verse(comprising_nodes[0], node["class"])
				else
					# 第３ニーファイ１章でなんか引っかかった。前は大丈夫だったのに
					next if node.child.nil?
					info = parse_verse(node, node["class"])
				end

				all_infos.push info
			elsif node["class"] == "summary"
				@log.info(node["class"])
				summary_node = check_and_get_child(node) # divの子供はp要素を持っている
				info = parse_verse(summary_node, node["class"])
				all_infos.push info
			elsif (node["class"] == "verses" || node["class"] == "article") && node["id"] == "0"
				@log.info("- #{node["class"]}")
				infos = parse_verses(node, node["class"]) # div要素
				all_infos.push *infos
			elsif node["class"] == "verses maps"
				@log.info("- #{node["class"]}")
				infos = parse_verses(node, 'maps') # div要素
				all_infos.push *infos
			else
				@log.info("node: #{node.name}")
				@log.info("id: #{node['id']}")
				@log.info("class: #{node['class']}")
				raise 'Unknown node'
			end

			if @state == STATE_BOOK_CHANGE
				@log.info("loop break")
				break
			end
		end
		all_infos
	end

end