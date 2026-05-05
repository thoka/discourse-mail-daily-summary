# frozen_string_literal: true

module MailDailySummaryHelper
  ELLIPSIS = "…"

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
        maximum_length = SiteSetting.mail_daily_summary_max_excerpt_length.to_i
        source_html = post.cooked.to_s

        if minimum_length <= 0
          if maximum_length > 0
            excerpt_html = daily_summary_plain_text_excerpt_from(source_html, maximum_length)
            { html: excerpt_html, truncated: excerpt_html != source_html }
          else
            { html: source_html, truncated: false }
          end
        else
          selected_html =
            daily_summary_first_paragraphs_from(
              post.cooked,
              minimum_length,
            ).to_s

          excerpt_html = selected_html.presence || source_html

          if maximum_length > 0 && daily_summary_text_length_for(excerpt_html) > maximum_length
            excerpt_html = daily_summary_plain_text_excerpt_from(source_html, maximum_length)
          end

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

  def daily_summary_plain_text_excerpt_from(html, maximum_length)
    text = daily_summary_plain_text_from(html)

    return text if maximum_length <= 0 || text.length < maximum_length
    return "" if maximum_length <= 1
    return ELLIPSIS if maximum_length == 2

    cutoff = text[0, maximum_length - 2]
    boundary = cutoff.rindex(/\s/)

    base_excerpt =
      if boundary && boundary.positive?
        cutoff[0...boundary].rstrip
      else
        cutoff.rstrip
      end

    base_excerpt = cutoff.rstrip if base_excerpt.blank?
    "#{base_excerpt}#{ELLIPSIS}"
  end

  def daily_summary_text_length_for(html)
    daily_summary_plain_text_from(html).length
  end

  def daily_summary_plain_text_from(html)
    Nokogiri.HTML5(html.to_s).text.gsub(/\s+/, " ").strip
  end
end
