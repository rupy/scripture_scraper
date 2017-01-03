require 'logger'

class ParseBase

	RETRY_TIME = 3

	def initialize
		# ロガーの初期化
		@log = Logger.new(STDERR)
		@log.level=Logger::DEBUG
	end
	
	def try_and_retry
		# 立て続けにたくさんのデータを取ってきていると、エラーを出すことがある。
		# その場合にはしばらく待って、再度実行する

		retry_count = 0
		resp = nil
		begin
			resp = yield
		rescue => e
			print "retry" if retry_count == 0
			print "."
			sleep(RETRY_TIME * retry_count)
			retry_count += 1
			retry
		end
		puts "" if retry_count > 0
		resp
	end

	def check_and_get_child(node)
		if node.children.length == 1
			return node.child
		else
			raise "node '#{node.to_html}' has multiple children"
		end
	end

	def empty_text_node?(node)
		if node.name == "text"
			if node.inner_html == ""
				return true
			else
				raise 'Unknown text node'
			end
		end
		false
	end

	# 順に前の兄弟ノードのテキスト数をカウントしていく
	def position_count(node)
		pos = 0
		sib = node.previous_sibling
		until sib.nil?
			# puts sib.to_html
			raise "non-text node '#{sib.to_html}' found while counting posision" unless sib.name == 'text'
			pos += sib.content.length
			# puts sib.path
			sib = sib.previous_sibling
		end
		pos
	end

	def unwrap(node)
		node.swap(node.children)
	end

	def check_children_contain_tag(node)
		node.children.to_a.any?{|c| c.name != 'text'}
	end

	def remove_spaces(verse_node)
		verse_node.children.each do |node|
			if node.name == 'text' && node.to_html =~ /\A\s+\z/
				node.remove
				# @log.debug("del space node: '#{node.to_html}'")
			end
		end
	end


end