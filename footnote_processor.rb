require './parse_base'
require './footnote_web_fetcher'
require './footnote_box'

class FootnoteProcessor < ParseBase

	ALLOWED_NODE_TYPE = ['text', 'ruby', 'span']

	def initialize
		super
	end

	def get_footnote(url)

		fwf = FootnoteWebFetcher.new
		fwf.fetch_and_store url
		web_data = fwf.read_footnote_data(url)

		fb = FootnoteBox.new
		footnote_content, fn_ref_infos, fn_st_infos = fb.parse_footnote_contents web_data

		[footnote_content, fn_ref_infos, fn_st_infos]
	end

	def get_anchor_node_and_pos(sup_node)
		anchor_node = sup_node.next_sibling
		if anchor_node.nil? # マラキの最後にはfootnoteのマーカーがあとに来るスタイルのものがある
			anchor_node = sup_node.previous_sibling
			raise 'invalid footnote found' if anchor_node.nil?
			pos = position_count anchor_node
		else # 通常はこちら
			pos = position_count sup_node
		end

		# anchorはaタグ
		raise "invlalid footnote found '#{anchor_node.to_html}'" unless anchor_node.name == 'a'

		return [anchor_node, pos]
	end

	def extract_text(anchor_node)
		# 脚注にかかっているテキストを抽出する

		if check_children_contain_tag anchor_node
			@log.debug("nest footnote found")
			raise "unknown footnote nest found #{anchor_node.parent.to_html}" if anchor_node.children.to_a.any?{|c| !ALLOWED_NODE_TYPE.include? c.name }
			text = anchor_node.inner_text
			# raise "non-text node found in #{anchor_node.to_html}"
		else
			text = anchor_node.inner_html
		end
		text
	end

	def check_if_marker_contains_no_tags(sup_node)
		if check_children_contain_tag sup_node # 教義と聖約はmarkerタグを含んでいるけれど予め削除しているので問題ない	
			raise "non-text node found in #{sup_node.to_html}"
		end
	end

	def process_footnote(sup_node)

		# TODO: 注の付いているテキストの取り出し方を考える必要あり

		@log.debug("footnote found")

		check_if_marker_contains_no_tags sup_node
		marker = sup_node.inner_html

		anchor_node, pos = get_anchor_node_and_pos sup_node

		href = anchor_node['href']
		rel = anchor_node['rel']

		text = extract_text anchor_node


		length = text.length

		sup_node.remove
		unwrap anchor_node

		footnote, fn_ref_infos, fn_st_infos = get_footnote rel
		# footnote = 'none'

		footnote_info = {marker: marker, href: href, rel: rel, footnote: footnote, fn_ref_infos: fn_ref_infos, fn_st_infos: fn_st_infos, pos: pos, length: length, text: text}
	end
end