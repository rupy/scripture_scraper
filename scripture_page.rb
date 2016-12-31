require 'nokogiri'
require './parse_base'
require './ruby_processor'
require './reference_processor'
require './style_processor'
require './footnote_processor'
require './chronicle_processor'

class ScripturePage < ParseBase

	STATE_NORMAL = 0
	STATE_BOOK_CHANGE = 1

	def initialize(lang, title, book, state=STATE_NORMAL)
		# ロガーの初期化
		@log = Logger.new(STDERR)
		@log.level=Logger::DEBUG

		@lang = lang
		@title = title
		@book = book
		@state = state

		puts state
	end

	def parse_verse(verse_node, type='verse')

		# puts verse_node.to_html
		# 先頭のAタグの削除
		anchor_node = verse_node.at_css("a.dontHighlight")
		unless anchor_node.nil?
			anchor_node.remove
			verse_name = anchor_node['name']
		end
		if verse_name == 'closing' # 三人の証人の証で登場
			@log.info("closing paragraph found ... skip")
			return nil
		end
		if verse_node.child.name == 'p'
			@log.info("nesting paragraph found ... skip")
			return nil
		end
		if verse_node.inner_text =~ /^\s$/
			# D&C102章は署名の前にからの段落があるのでここで飛ばす
			@log.info("empty paragraph found ... skip: '#{verse_node.inner_html}'")
			return nil
		end

		# 先頭の節番号の削除
		span_node = verse_node.at_css("span.verse")
		unless span_node.nil?
			span_node.remove 
			verse_num = span_node.inner_html
			verse_num.gsub!(/\u00A0/,"")
			raise 'non-number verse num found' unless verse_num =~ /^\d+$/
		end

		# if @lang == 'jpn'
		# 	ruby_process verse_node
		# end


		# 預言者ジョセフ・スミスの証の2重span解消
		language_node = verse_node.at_css("span.langauge") # languageのタイポだと思われる
		unless language_node.nil?
			language_node.swap language_node.children
		end

		# 教義と聖約はsupの中にmarkerタグを含んでいるので削除
		marker_nodes = verse_node/"marker"
		marker_nodes.each do |marker_node|
			unwrap marker_node
		end

		br_nodes = verse_node/'br'
		unless br_nodes.nil?
			br_nodes.each do |br_node|
				br_node.remove
				@log.info('removed br node')
			end
		end

		# なぜかアブラハム書のタイトルに<div eid="" >が追加されててエラーになったので対処
		eid_nodes = verse_node/"div[@eid]"
		unless eid_nodes.nil?
			eid_nodes.each do |eid_node|
				unwrap eid_node
			end
		end

		footnote_infos = []
		style_infos = []
		ref_infos = []
		begin
			redo_flag = false # 初めfalseにしておかなけれannotationが一切見つからなかった時に無限ループになる
			annotation_nodes = verse_node.xpath("./*[((name()='b')or(name()='span')or(name()='em')or(name()='sup')or(name()='ruby')or((name()='a')and((@class='scriptureRef')or(@href='#note'))))]") # この書き方でないと順番がめちゃくちゃになる
			annotation_nodes.each do |annotation_node|

				# 子供が複数見つかった時にはタグが入れ子になっているのであとでやり直さなければいけない
				# 子供が一つでも子供がtextノード出ない場合は入れ子になっている（歴代史下17:4で登場）
				# xpathによるタグの取得自体からやり直す理由はswapによってannotation_nodeの中身が空っぽになってしまうため処理が施せないことによる
				redo_flag = annotation_node.children.length > 1
				redo_flag |= check_children_contain_tag annotation_node

				if annotation_node.name == 'em' || annotation_node.name == 'span' || annotation_node.name == 'b'
					# 文字修飾関係の処理
					sp = StyleProcessor.new
					style_info = sp.process_style annotation_node
					style_infos.push style_info
				elsif annotation_node.name == 'sup' && annotation_node['class'] == 'studyNoteMarker'

					# footnoteの中にタグが含まれている
					anchor_node = annotation_node.next_sibling
					anchor_node = annotation_node.previous_sibling if anchor_node.nil?
					raise 'invalid footnote found' if anchor_node.nil?
					redo_flag |= anchor_node.children.length != 1
					redo_flag |= anchor_node.children.to_a.any?{|c| c.name != 'text'}
					# 脚注の処理
					fp = FootnoteProcessor.new @lang
					footnote_info = fp.process_footnote annotation_node
					footnote_infos.push footnote_info
				elsif annotation_node.name == 'a' && annotation_node['class'] == 'scriptureRef'
					# 聖文中で他の聖文が引用されている部分のリンクの処理
					rp = ReferenceProcessor.new
					ref_info = rp.process_ref annotation_node
					ref_infos.push ref_info
				elsif annotation_node.name == 'a' && annotation_node['href'] == '#note' && annotation_node['class'] != 'footnote'
					puts 'aaa'
					# ジョセフ・スミス歴史で出てくるnoteの処理	
					rp = ReferenceProcessor.new
					ref_info = rp.process_ref annotation_node
					ref_infos.push ref_info
				elsif annotation_node.name == 'a' && annotation_node['href'] == '#note' && annotation_node['class'] == 'footnote' && annotation_node.inner_text == ''
					# 英語の雅歌で出てくる空っぽのノード
					unwrap annotation_node
				elsif annotation_node.name == 'a' && annotation_node['class'] == 'footnote'
					# マラキの終わりにある特殊な脚注
					next
				elsif annotation_node.name == 'ruby'
					if annotation_node.children.length == 1 && annotation_node.child.name == 'text' # 1ne1:19でrubyタグが分離している部分がある
						if annotation_node.next_sibling.name == 'ruby'
							@log.debug('split ruby found')
							annotation_node.next_sibling.child.add_previous_sibling annotation_node.child
							parent = annotation_node.parent
							annotation_node.remove
							puts parent.to_html
							next
						else
							raise 'invalid ruby found'
						end
					end
					rp = RubyProcessor.new
					rp.ruby_process annotation_node
				else
					raise 'Unknown annotation found'
				end

				if redo_flag
					# @log.debug("Annotation process redo:")
					print '+'
					# @log.debug("#{verse_node.to_html}")
					break
				end
			end
		end while redo_flag

		text = verse_node.inner_html

		if verse_node.child.name == 'img'
			@log.debug("img tag found")
			img_node = check_and_get_child(verse_node)
			src = img_node['src']
			alt = img_node['alt']
			img_info = "{src=#{src},alt=#{alt}}"
			text = img_info
		end

		# 特殊な文字を置き換える
		# nbsp_char_pattern = /[\u00A0]/
		# if text =~ nbsp_char_pattern
		# 	@log.info("nbsp chars found")
		# 	text.gsub!(nbsp_char_pattern, " ")
		# end

		# puts "++++++++++++++++++"

		# puts text
		# puts verse_name
		# puts verse_num
		# print footnote_markers, footnote_hrefs, footnote_rels, footnote_words
		# puts

		raise "Unknown tag '#{$1}' found in '#{text}'" if text =~ /(<[^>]+>)/

		info = {
			verse_name: verse_name,
			verse_num: verse_num,
			type: type,
			footnote_infos: footnote_infos,
			style_infos: style_infos,
			ref_infos: ref_infos,
			text: text
		}
	end

	def build_info(
		verse_name: nil,
		verse_num: nil,
		type: nil,
		footnote_infos: nil,
		style_infos: nil,
		ref_infos: nil,
		text: nil)
		
		info = {
			verse_name: verse_name,
			verse_num: verse_num,
			type: type,
			footnote_infos: footnote_infos,
			style_infos: style_infos,
			ref_infos: ref_infos,
			text: text
		}
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
		if @state == STATE_NORMAL
			# タイトルの部分を取得
			detail = doc/"div[@id='details']//h1"
			info = parse_verse(detail[0], 'title')
			title_name = info[:text]
			@log.info("@@ #{title_name} @@")

		else
			book_list = ['three', 'eight', 'js']
			# 日本語の３人の証人の証
			if @title == 'bom' && book_list.include?(@book) && @lang == 'jpn'
				book_idx = book_list.index @book
				puts book_idx
				# タイトルの部分を取得
				content = content/"div[@class='topic']"
				h2_nodes = content[book_idx]/'h2'
				info = parse_verse(h2_nodes[1], 'title')
				title_name = info[:text]
				@log.info("@@ #{title_name} @@")
				h2_nodes.remove
				@log.info("finish")
				infos = parse_verses(content[book_idx], 'article')

				if @book == 'js'
					@log.info("finish changing")
					@state = STATE_NORMAL
				else
					@log.info("start changing book")
				end
			else
				raise 'invalid state'
			end

			all_infos = [info] + infos

			return all_infos
		end
		all_infos = [info]
		content.children.each do |node|

			line = nil

			# textノードを飛ばす
			next if empty_text_node? node

			next if node.name == "div" && node["id"] == "media"
			next if node.name == "div" && node["id"] == "audio-player"
			next if node.name == "div" && node["class"] == "audio-player" # 日本語1Ne1で登場
			next if node.name == "ul" && node["class"].start_with?("prev-next")

			if @book == 'chron-order'
				cp = ChronicleProcessor.new
				infos = cp.parse_chr node
				all_infos.push *infos
			elsif node.name == "h2"
				@log.info("chapter_title")
				# puts node.inner_html
				info = build_info(type: "chapter_title", text: node.inner_html)
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
				# puts node.to_html
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