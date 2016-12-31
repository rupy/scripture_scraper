require 'logger'
require './parse_base'

class ChronicleProcessor

	def parse_chr_table(table_node)

		all_chr_ref_infos = []
		output = ''
		row_concat_count_arr = [0, 0, 0, 0]
		table_node.children.each_with_index do |tr_node|

			chr_ref_infos = []
			next if empty_text_node? tr_node

			col_idx = 0
			output += '|'
			tr_node.children.each_with_index do |td_node|
				next if empty_text_node? td_node

				if row_concat_count_arr[col_idx] > 0
					row_concat_count_arr[col_idx] -= 1
					output += 'v|'
					col_idx += 1
				end

				cell_type = td_node.name
				col_span = td_node['colspan'].to_i
				row_span = td_node['rowspan'].to_i

				if row_span.to_i > 0
					raise 'row concatination error ocurred' if row_concat_count_arr[col_idx] > 0
					row_concat_count_arr[col_idx] = row_span - 1
				end


				td_node.children.each do |p_node|
					next if empty_text_node? p_node
					# 先頭のAタグの削除
					anchor_node = p_node.at_css("a.dontHighlight")
					unless anchor_node.nil?
						anchor_node.remove
					end
					p_node.children.each do |cell_node|
						next if empty_text_node? p_node
						output += cell_node.content
						if col_idx == 3 && cell_node.name == 'a' && cell_node['class'] == 'scriptureRef'
							# 聖文中で他の聖文が引用されている部分のリンクの処理
							rp = ReferenceProcessor.new
							ref_info = rp.process_ref cell_node
							chr_ref_infos.push ref_info
						elsif col_idx == 3 && cell_node.name == 'a' && cell_node['href'] == '#note'
							# 聖文中で他の聖文が引用されている部分のリンクの処理
							rp = ReferenceProcessor.new
							ref_info = rp.process_ref cell_node
							chr_ref_infos.push ref_info
						end
					# puts td_node.to_html
					end
				end
				(col_span-1).times do
					output += '|>'
				end
				output += '|'
				col_idx += col_span
				all_chr_ref_infos.push chr_ref_infos
			end
			output += "\n"
		end
		# print all_chr_ref_infos
		build_info text: output
	end

	def parse_chr(chr_node)
		infos = []
		if chr_node.name == 'div' && chr_node["class"] == "article"
			chr_node.children.each do |div_node|
				next if empty_text_node? div_node
				if div_node.name == 'div' && div_node["class"] == "figure"
					div_node.children.each do |child_node|
						next if empty_text_node? child_node
						if child_node.name == 'table' && child_node["class"] == "lds-table"
							info = parse_chr_table child_node
							infos.push info
						elsif child_node.name == 'b'
							next
						elsif child_node.name == 'div'
							span_node = child_node.at_xpath("span")
							# aタグは削除する
							a_node = span_node.child
							unwrap a_node
							# 再度spanを取得し段落の中に入れる
							span_node = child_node.at_xpath("span")
							p_node = child_node.at_xpath("p")
							p_node.child.after span_node

							info = parse_verse child_node.child
							infos.push info
						else
							raise "Unknown node '#{child_node.to_html}' found"
						end
					end
				else
					raise "Unknown node '#{div_node.to_html}' found"
				end
			end
		else
			raise "Unknown node '#{chr_node.to_html}' found"
		end
		infos
	end	
end