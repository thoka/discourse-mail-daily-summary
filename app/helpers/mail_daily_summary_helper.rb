# frozen_string_literal: true

module MailDailySummaryHelper
  def daily_summary_topic(topic, count)
    render(partial: "daily_summary_topic", locals: { topic: topic })
  end

  def daily_summary_posts(topic)
    max_posts = SiteSetting.mail_daily_summary_max_posts_per_topic.to_i
    posts = topic.posts.sort_by(&:post_number)

    return posts if max_posts <= 0

    posts.first(max_posts)
  end

  def daily_summary_post_excerpt(post)
    PrettyText.format_for_email(daily_summary_excerpt_data(post)[:html], post).html_safe
  end

  def daily_summary_topic_cut_off?(topic)
    shown_posts = daily_summary_posts(topic)

    return true if topic.posts.size > shown_posts.size

    shown_posts.any? { |post| daily_summary_excerpt_data(post)[:truncated] }
  end

  private

  def daily_summary_excerpt_data(post)
    @daily_summary_excerpt_data ||= {}

    @daily_summary_excerpt_data[post.id] ||=
      begin
        minimum_length = SiteSetting.mail_daily_summary_min_excerpt_length.to_i
        source_html = post.cooked.to_s

        if minimum_length <= 0
          { html: source_html, truncated: false }
        else
          selected_html =
            daily_summary_first_paragraphs_from(
              post.cooked,
              minimum_length,
            ).to_s

          excerpt_html = selected_html.presence || source_html

          { html: excerpt_html, truncated: excerpt_html != source_html }
        end
      end
  end

  def daily_summary_first_paragraphs_from(html, minimum_length)
    doc = Nokogiri.HTML5(html)

    result = +""
    length = 0

    doc
      .css("body > p, aside.onebox, body > ul, body > blockquote")
      .each do |node|
        next if node.text.blank?

        result << node.to_s
        length += node.inner_text.length
        return result if length >= minimum_length
      end

    return result if result.present?

    doc.css("body > p:not(:empty), body > div:not(:empty), body > p > div.lightbox-wrapper img").first
  end
end
