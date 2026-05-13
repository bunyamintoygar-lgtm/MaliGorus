CREATE OR REPLACE FUNCTION get_chat_list(
  p_user_id UUID,
  p_search_query TEXT DEFAULT NULL,
  p_page INT DEFAULT 0,
  p_page_size INT DEFAULT 20
)
RETURNS TABLE (
  partner_id UUID,
  partner_name TEXT,
  partner_avatar TEXT,
  partner_title TEXT,
  last_message_body TEXT,
  last_message_time TIMESTAMP WITH TIME ZONE,
  unread_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  WITH conversations AS (
    -- Her partner ile olan son mesaj zamanını bul
    SELECT 
      CASE 
        WHEN sender_id = p_user_id THEN receiver_id 
        ELSE sender_id 
      END AS partner_id,
      MAX(created_at) as last_msg_time
    FROM messages
    WHERE sender_id = p_user_id OR receiver_id = p_user_id
    GROUP BY 1
  ),
  unread_counts AS (
    -- Her partnerden gelen okunmamış mesajları say
    SELECT 
      sender_id as partner_id,
      COUNT(*) as count
    FROM messages
    WHERE receiver_id = p_user_id AND is_read = false
    GROUP BY 1
  ),
  latest_messages AS (
    -- Her partner ile olan son mesaj içeriğini al
    SELECT DISTINCT ON (
      CASE WHEN sender_id = p_user_id THEN receiver_id ELSE sender_id END
    )
      CASE WHEN sender_id = p_user_id THEN receiver_id ELSE sender_id END as partner_id,
      body,
      created_at
    FROM messages
    WHERE sender_id = p_user_id OR receiver_id = p_user_id
    ORDER BY CASE WHEN sender_id = p_user_id THEN receiver_id ELSE sender_id END, created_at DESC
  )
  SELECT 
    c.partner_id,
    COALESCE(p.full_name, 'Kullanıcı') as partner_name,
    p.avatar_url as partner_avatar,
    p.profession as partner_title,
    lm.body as last_message_body,
    c.last_msg_time as last_message_time,
    COALESCE(uc.count, 0)::BIGINT as unread_count
  FROM conversations c
  JOIN latest_messages lm ON lm.partner_id = c.partner_id
  LEFT JOIN profiles p ON p.id = c.partner_id
  LEFT JOIN unread_counts uc ON uc.partner_id = c.partner_id
  WHERE 
    p_search_query IS NULL 
    OR p_search_query = ''
    OR p.full_name ILIKE '%' || p_search_query || '%'
  ORDER BY c.last_msg_time DESC
  LIMIT p_page_size
  OFFSET p_page * p_page_size;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;