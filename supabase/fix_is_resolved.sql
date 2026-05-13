UPDATE discussions d SET is_resolved = true FROM discussion_replies r WHERE r.discussion_id = d.id AND d.type = 'danisma';
