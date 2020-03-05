require_relative "test_helper"

class ActionTextTest < Minitest::Test
  def setup
    skip unless defined?(ActionText)
  end

  def test_works
    user = User.create!(content: "hi")
    assert_equal "<div class=\"trix-content\">\n  hi\n</div>\n", user.content.body.to_s
  end
end
