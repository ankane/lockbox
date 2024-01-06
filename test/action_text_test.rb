require_relative "test_helper"

class ActionTextTest < Minitest::Test
  def setup
    skip unless defined?(ActionText)
  end

  def test_create
    user = User.create!(content: "hi")
    assert_equal "<div class=\"trix-content\">\n  hi\n</div>\n", user.content.body.to_s
  end

  # if encrypted, the ciphertext will change when the content is the same
  def test_encrypted
    user = User.create!(content: "hi")
    original_ciphertext = user.content.body_ciphertext
    user.update!(content: "hi")
    refute_equal user.content.body_ciphertext, original_ciphertext
  end

  def test_encoding
    require "action_text/version"
    skip if ActionText::VERSION::MAJOR < 7

    user = User.create!(content: "ルビー")
    assert_equal "<div class=\"trix-content\">\n  ルビー\n</div>\n", user.content.body.to_s
    assert_equal user.content.to_trix_html, "ルビー"

    user.reload
    assert_equal "<div class=\"trix-content\">\n  ルビー\n</div>\n", user.content.body.to_s
    assert_equal user.content.to_trix_html, "ルビー"
  end
end
