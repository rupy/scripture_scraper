require './footnote_reference_processor'

class FootnoteBox < ParseBase

	def initialize
		super
	end

	def get_footnote(doc)
		# footnoteの部分を取得
		footnotes = doc.xpath("//div[@class='footnotes']//span[(@class='block')or(@class='div')]")

		if footnotes.size > 1
			raise 'footnote is not only one'
		elsif footnotes.empty? # エテル5章4節の脚注が空
			nil
		else
			footnotes[0]
		end
	end

	def remove_head_space_text_node(footnote)

		if footnote.child.name == 'text' && footnote.child.to_html =~ /^\s+$/
			footnote.child.remove
		end
	end

	def parse_footnote_contents(web_data)
		#ドキュメント全体を取得
		doc = Nokogiri::HTML.parse(web_data, nil)

		footnote = get_footnote doc

		# エテル5章4節の脚注が空
		if footnote.nil?
			@log.debug("Footnote is empty")
			return ["", [], []] 
		end

		remove_head_space_text_node footnote

		fn_ref_infos = []
		fn_st_infos = []
		begin
			redo_flag = false
			annotation_nodes = footnote.xpath("./*[(name()='span')or(name()='em')or(name()='a')]") # この書き方でないと順番がめちゃくちゃになる
			annotation_nodes.each do |annotation_node|
				redo_flag = annotation_node.children.length != 1
				redo_flag |= check_children_contain_tag annotation_node

				if annotation_node.name == 'a' && annotation_node['class'] == 'load'
					# footnote中のリファレンス
					frp = FootnoteReferenceProcessor.new
					fn_ref_info = frp.process_fn_ref annotation_node
					fn_ref_infos.push fn_ref_info
				elsif annotation_node.name == 'span' || annotation_node.name == 'em'
					# footnote中のスタイル
					sp = StyleProcessor.new
					fn_st_info = sp.process_style annotation_node
					fn_st_infos.push fn_st_info
				else
					raise 'Unknown annotation found'
				end
				if redo_flag
					@log.debug("Footnote annotation process redo: #{footnote.to_html}")
					break
				end
			end
		end while redo_flag

		[footnote.content, fn_ref_infos, fn_st_infos]
	end
end