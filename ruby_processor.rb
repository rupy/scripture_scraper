require './parse_base'

class RubyProcessor < ParseBase

	# 最終的に残すタグ（spanやbはあとで処理してもらえる）
	ALLOWED_NODE_TYPE = ['text', 'b', 'span']

	def initialize
		super
	end

	def remove_empty_ruby_nodes(ruby_node)

		ruby_node.children.each do |ruby_node_child|
			# ルビが空っぽ
			if ruby_node_child.name == 'text' && ruby_node_child.content =~ /^\s*$/
				@log.info('empty ruby child node... skip')
				ruby_node_child.remove
			end
		end
	end

	def check_if_correct_ruby_structure(ruby_node)

		# 4でない場合はなにか他のタグを含んでいるので警告程度に出力
		unless ruby_node.children.length == 4
			@log.info("ruby node num is #{ruby_node.children.length}")
		end
	end

	def decompose_ruby_structure(ruby_node)
		node_num = ruby_node.children.length

		# ruby_nodeの初めのノードはふりがなが付くノード
		rp_begin_node = ruby_node.children[node_num - 3]
		furigana_node = ruby_node.children[node_num - 2]
		rp_end_node = ruby_node.children[node_num - 1]

		unless rp_begin_node.name == 'rp' && furigana_node.name == 'rt' && rp_end_node.name == 'rp'
			raise "invalid ruby found in '#{ruby_node.to_html}'"
		end

		[rp_begin_node, furigana_node, rp_end_node]
	end

	def check_if_not_cotains_tag(node)
		if node.children.to_a.any?{|c| !ALLOWED_NODE_TYPE.include? c.name }
			raise "invalid tag found in '#{node.to_html}'"
		end
	end

	def ruby_process(ruby_node)

		# TODO: 今はルビ情報は保持していない。ただ不要な情報を削除するだけ。保持できるように変更する。
		# @log.debug("ruby found")

		# 空のrubyタグを削除する
		remove_empty_ruby_nodes ruby_node

		# rubyの構造をチェックする
		check_if_correct_ruby_structure ruby_node

		# ルビ構造を取り出す
		rp_begin_node, furigana_node, rp_end_node = decompose_ruby_structure ruby_node

		# いらないタグは削除
		rp_begin_node.remove
		furigana_node.remove
		rp_end_node.remove

		check_if_not_cotains_tag ruby_node

		# rubyタグ自体の削除
		unwrap ruby_node
	end
end

