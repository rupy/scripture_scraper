require './parse_base'
require './annotation_processor'
require './chronicle_processor'
require './japanese_introduction_processor'


module VerseProcessor

	def get_verse_name_and_remove_dont_highlight_anchor(verse_node)
		# 先頭のAタグの削除
		anchor_node = verse_node.at_css("a.dontHighlight")
		unless anchor_node.nil?
			anchor_node.remove
			verse_name = anchor_node['name']
		end
		verse_name
	end

	def get_verse_number_and_remove_span(verse_node)
		# 先頭の節番号の削除
		span_node = verse_node.at_css("span.verse")
		unless span_node.nil?
			span_node.remove 
			verse_num = span_node.inner_html
			verse_num.gsub!(/\u00A0/,"")
			raise 'non-number verse num found' unless verse_num =~ /^\d+$/
		end
		verse_num
	end

	def remove_duplicated_span(verse_node)

		# 預言者ジョセフ・スミスの証の2重span解消
		language_node = verse_node.at_css("span.langauge") # languageのタイポだと思われる
		unless language_node.nil?
			unwrap language_node
		end
	end

	def remove_marker(verse_node)
		marker_nodes = verse_node/"marker"
		marker_nodes.each do |marker_node|
			unwrap marker_node
		end
	end

	def replace_br_with_newline(verse_node)
		br_nodes = verse_node/'br'
		unless br_nodes.nil?
			br_nodes.each do |br_node|
				br_node.replace("\n")
				@log.info('replace br node with newline')
			end
		end
	end

	def remove_empty_div(verse_node)
		eid_nodes = verse_node/"div[@eid]"
		unless eid_nodes.nil?
			eid_nodes.each do |eid_node|
				unwrap eid_node
			end
		end
	end

	def split_text_by_zero_width_space(text)
		@log.debug("split #{text.split(/[\u200b]/)}")
	end

	def remove_zero_width_space(text)
		text.gsub!(/[\u200b]/,'')
	end

	def parse_verse(verse_node, type='verse')

		# puts verse_node.content
		# 先頭のAタグの削除
		verse_name = get_verse_name_and_remove_dont_highlight_anchor verse_node

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
		verse_num = get_verse_number_and_remove_span verse_node

		# 預言者ジョセフ・スミスの証の2重span解消
		remove_duplicated_span verse_node

		# 教義と聖約はsupの中にmarkerタグを含んでいるので削除
		remove_marker verse_node

		# brの削除
		# TODO: 改行コードに変換したほうがいいんじゃないの？
		replace_br_with_newline verse_node

		# なぜかアブラハム書のタイトルに<div eid="" >が追加されててエラーになったので対処
		remove_empty_div verse_node

		# アノテーションの処理
		ap = AnnotationProcessor.new
		footnote_infos, style_infos, ref_infos = ap.process_annotations verse_node

		remove_spaces verse_node

		text = verse_node.inner_html
		text.strip!

		# split_text_by_zero_width_space text
		remove_zero_width_space text

		# 画像を置き換える
		if verse_node.child.name == 'img'
			@log.debug("img tag found")
			img_node = check_and_get_child(verse_node)
			src = img_node['src']
			alt = img_node['alt']
			img_info = "{src=#{src},alt=#{alt}}"
			text = img_info
		end

		# @log.debug(text.each_codepoint.map{|n| n.to_s(16) })



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
end