SELECT 
    {course}.shortname as 'Moodle Code',
    {course_categories}.path as 'Category Path',
    {course}.fullname as 'Course Name',
    (COALESCE(RESOURCES.count,0) + COALESCE(FOLDERS.count,0) +  COALESCE(BOOKS.count,0) +  COALESCE(PAGES.count,0) +  COALESCE(URLS.count,0)) as 'Resource Activities', GREATEST(COALESCE(GLOSSARIES.count,0) + COALESCE(POLLS.count,0) +  COALESCE(CHATS.count,0) +  COALESCE(FORUMS.count,0) +  COALESCE(FEEDBACKS.count,0) - 1,0) as 'Interactive Activities',
    COALESCE(QUIZ.count,0) as 'Quiz Activities',
    COALESCE(QGRADES.count,0) as 'Quiz Grades',
    COALESCE(TURNITIN.count,0) as 'Turnitin Activities',
    COALESCE(TGRADES.count,0) as 'Turnitin Grades',
    CASE
        WHEN {course}.visible = '0' THEN 'Hidden'
        WHEN {course}.visible = '1' THEN 'Published'
    END AS 'Publish State',
    COALESCE(PC.TotalStudents,0) as 'Active Students',
    CONCAT(ROUND(PC.Percent7Days),'%') as '% Students in Last 7 Days', 
    CONCAT(ROUND(PC.Percent30Days),'%') as '% Students in Last 30 Days',
    CONCAT(ROUND(PC.PercentQuarter),'%') as '% Students in Last Quarter',
    CONCAT(ROUND(PC.Percent365Days),'%') as '% Students in Last Year'
FROM {course}

JOIN {course_categories} ON {course}.category = {course_categories}.id

LEFT OUTER JOIN ( 
    SELECT courseid, COUNT(id) as count 
    FROM {grade_items} WHERE itemmodule = 'turnitintooltwo' 
    GROUP BY courseid 
) TURNITIN ON {course}.id = TURNITIN.courseid
LEFT OUTER JOIN (
    SELECT courseid, COUNT(*) as count FROM {grade_grades} 
    JOIN {grade_items} ON {grade_grades}.itemid = {grade_items}.id
    JOIN {course} ON {course}.id = {grade_items}.courseid
    WHERE 
        rawgrade IS NOT NULL
    AND itemmodule = 'turnitintooltwo'
    GROUP BY courseid
) TGRADES ON {course}.id = TGRADES.courseid

LEFT OUTER JOIN (
    SELECT course, COUNT(id) as count FROM {glossary} GROUP BY course 
    ) GLOSSARIES ON {course}.id = GLOSSARIES.course
    LEFT OUTER JOIN (
    SELECT course, COUNT(id) as count FROM {forum} GROUP BY course 
    ) FORUMS ON {course}.id = FORUMS.course
    LEFT OUTER JOIN (
    SELECT course, COUNT(id) as count FROM {chat} GROUP BY course 
    ) CHATS ON {course}.id = CHATS.course
    LEFT OUTER JOIN (
    SELECT course, COUNT(id) as count FROM {choice} GROUP BY course 
    ) POLLS ON {course}.id = POLLS.course
    LEFT OUTER JOIN (
    SELECT course, COUNT(id) as count FROM {feedback} GROUP BY course 
) FEEDBACKS ON {course}.id = FEEDBACKS.course

LEFT OUTER JOIN (
    SELECT course, COUNT(id) as count FROM {book} GROUP BY course 
    ) BOOKS ON {course}.id = BOOKS.course
    LEFT OUTER JOIN (
    SELECT course, COUNT(id) as count FROM {page} GROUP BY course 
    ) PAGES ON {course}.id = PAGES.course
    LEFT OUTER JOIN (
    SELECT course, COUNT(id) as count FROM {url} GROUP BY course 
    ) URLS ON {course}.id = URLS.course
    LEFT OUTER JOIN (
    SELECT course, COUNT(id) as count FROM {folder} GROUP BY course 
    ) FOLDERS ON {course}.id = FOLDERS.course
    LEFT OUTER JOIN (
    SELECT course, COUNT(id) as count FROM {resource} GROUP BY course 
) RESOURCES ON {course}.id = RESOURCES.course

LEFT OUTER JOIN ( 
    SELECT courseid, COUNT(id) as count 
    FROM {grade_items} WHERE itemmodule = 'quiz' 
    GROUP BY courseid 
) QUIZ ON {course}.id = QUIZ.courseid
LEFT OUTER JOIN (
    SELECT courseid, COUNT(*) as count FROM {grade_grades} 
    JOIN {grade_items} ON {grade_grades}.itemid = {grade_items}.id
    JOIN {course} ON {course}.id = {grade_items}.courseid
    WHERE 
    rawgrade IS NOT NULL
    AND itemmodule = 'quiz'
    GROUP BY courseid
) QGRADES ON {course}.id = QGRADES.courseid

JOIN
(
    SELECT {course}.id, coalesce(LA.ActiveStudents,0) as Last7days, coalesce(LAM.ActiveStudents,0) as Last30Days, EU.Total as TotalStudents, coalesce(LA.ActiveStudents/EU.Total*100,0) Percent7Days, coalesce(LAQ.ActiveStudents/EU.Total*100,0) PercentQuarter, coalesce(LAY.ActiveStudents/EU.Total*100,0) Percent365Days, coalesce(LAM.ActiveStudents/EU.Total*100,0) Percent30Days FROM {course}
    LEFT JOIN
    (
        SELECT 
            ULA.courseid, COUNT(DISTINCT U.id) as ActiveStudents
        FROM {user_lastaccess} ULA
        JOIN {user} U ON U.id = ULA.userid
        JOIN {user_info_data} UID ON U.id = UID.userid AND UID.fieldid = 1
        WHERE 
            ULA.timeaccess > (UNIX_TIMESTAMP(NOW()) - 86400*7)
        AND UID.data = 'Student'
        GROUP BY ULA.courseid
    ) LA
    ON {course}.id = LA.courseid

    LEFT JOIN
    (
        SELECT 
            ULA.courseid, COUNT(DISTINCT U.id) as ActiveStudents
        FROM {user_lastaccess} ULA
        JOIN {user} U ON U.id = ULA.userid
        JOIN {user_info_data} UID ON U.id = UID.userid AND UID.fieldid = 1
        WHERE 
            ULA.timeaccess > (UNIX_TIMESTAMP(NOW()) - 86400*30)
        AND UID.data = 'Student'
        GROUP BY ULA.courseid
    ) LAM
    ON {course}.id = LAM.courseid

    LEFT JOIN
    (
        SELECT 
            ULA.courseid, COUNT(DISTINCT U.id) as ActiveStudents
        FROM {user_lastaccess} ULA
        JOIN {user} U ON U.id = ULA.userid
        JOIN {user_info_data} UID ON U.id = UID.userid AND UID.fieldid = 1
        WHERE 
            ULA.timeaccess > (UNIX_TIMESTAMP(NOW()) - 86400*91)
        AND UID.data = 'Student'
        GROUP BY ULA.courseid
    ) LAQ
    ON {course}.id = LAQ.courseid

    LEFT JOIN
    (
        SELECT 
            ULA.courseid, COUNT(DISTINCT U.id) as ActiveStudents
        FROM {user_lastaccess} ULA
        JOIN {user} U ON U.id = ULA.userid
        JOIN {user_info_data} UID ON U.id = UID.userid AND UID.fieldid = 1
        WHERE 
            ULA.timeaccess > (UNIX_TIMESTAMP(NOW()) - 86400*365)
        AND UID.data = 'Student'
        GROUP BY ULA.courseid
    ) LAY
    ON {course}.id = LAY.courseid

    LEFT JOIN (
        SELECT DISTINCT c.id as course, COALESCE(count(DISTINCT u.id),0) as Total
        FROM {user} u
        JOIN {user_enrolments} ue ON ue.userid = u.id
        JOIN {enrol} e ON e.id = ue.enrolid
        JOIN {role_assignments} ra ON ra.userid = u.id
        JOIN {context} ct ON ct.id = ra.contextid AND ct.contextlevel = 50
        JOIN {course} c ON c.id = ct.instanceid AND e.courseid = c.id
        WHERE e.status = 0 AND u.suspended = 0 AND u.deleted = 0
        AND (ue.timeend = 0 OR ue.timeend > NOW()) AND ue.status = 0
        AND ra.roleid = 5
        GROUP by c.id
    ) EU
    ON {course}.id = EU.course
    JOIN {course_categories} ON {course}.category = {course_categories}.id
) PC ON {course}.id = PC.id 

WHERE
    shortname LIKE :shortname_filter
    AND 
    path like :path_filter
ORDER BY 
    shortname
