
SELECT 
    mdl_course.shortname as 'Moodle Code',
    mdl_course.fullname as 'Course Name',

    ###
    ### To help with reporting we add a custom Course Type label
    ### Change the filters and remove the #s from the following lines:
    ###
    #CASE
    #    WHEN LEFT(mdl_course.shortname,2)='SC' THEN 'Short Course'
    #    WHEN LEFT(mdl_course.shortname,2)='AP' THEN 'Apprenticeship'
    #    WHEN LEFT(mdl_course.shortname,2)='FE' THEN 'Further Education'
    #    WHEN LEFT(mdl_course.shortname,2)='FU' THEN 'Further Unit'
    #    WHEN LEFT(mdl_course.shortname,2)='FX' THEN 'Further Extension'
    #    WHEN LEFT(mdl_course.shortname,2)='HE' THEN 'Higher Programme'
    #    WHEN LEFT(mdl_course.shortname,2)='HM' THEN 'Higher Brighton Module'
    #    WHEN LEFT(mdl_course.shortname,2)='HR' THEN 'Higher RAU Module'
    #    WHEN LEFT(mdl_course.shortname,2)='SS' THEN 'Student Support'
    #    WHEN LEFT(mdl_course.shortname,2)='14' THEN '14+ Programme'
    #END AS 'Course Type',

    (COALESCE(RESOURCES.count,0) + COALESCE(FOLDERS.count,0) +  COALESCE(BOOKS.count,0) +  COALESCE(PAGES.count,0) +  COALESCE(URLS.count,0)) as 'Resource Activities', GREATEST(COALESCE(GLOSSARIES.count,0) + COALESCE(POLLS.count,0) +  COALESCE(CHATS.count,0) +  COALESCE(FORUMS.count,0) +  COALESCE(FEEDBACKS.count,0) - 1,0) as 'Interactive Activities',
    COALESCE(QUIZ.count,0) as 'Quiz Activities',
    COALESCE(QGRADES.count,0) as 'Quiz Grades',
    COALESCE(TURNITIN.count,0) as 'Turnitin Activities',
    COALESCE(TGRADES.count,0) as 'Turnitin Grades',
    CONCAT(?,mdl_course.id) as href,
    mdl_course.visible,
    CASE
        WHEN mdl_course.visible = '0' THEN 'Hidden'
        WHEN mdl_course.visible = '1' THEN 'Published'
    END AS 'Publish State',
    COALESCE(PC.TotalStudents,0) as 'Active Students',
    CONCAT(ROUND(PC.Percent7Days),'%') as '% Students in Last 7 Days', 
    CONCAT(ROUND(PC.Percent30Days),'%') as '% Students in Last 30 Days'
FROM mdl_course

###
### Join with course categories so we can filter by paths
###
JOIN mdl_course_categories ON mdl_course.category = mdl_course_categories.id

###
### Turnitin Audit
###
LEFT OUTER JOIN ( 
    SELECT courseid, COUNT(id) as count 
    FROM mdl_grade_items WHERE itemmodule = 'turnitintooltwo' 
    GROUP BY courseid 
) TURNITIN ON mdl_course.id = TURNITIN.courseid
LEFT OUTER JOIN (
    SELECT courseid, COUNT(*) as count FROM mdl_grade_grades 
    JOIN mdl_grade_items ON mdl_grade_grades.itemid = mdl_grade_items.id
    JOIN mdl_course ON mdl_course.id = mdl_grade_items.courseid
    WHERE 
        rawgrade IS NOT NULL
    AND itemmodule = 'turnitintooltwo'
    # AND mdl_grade_grades.timemodified<1478476800 
    GROUP BY courseid
) TGRADES ON mdl_course.id = TGRADES.courseid

###
### Interacive Activities Audit
###
LEFT OUTER JOIN (
    SELECT course, COUNT(id) as count FROM mdl_glossary GROUP BY course 
    ) GLOSSARIES ON mdl_course.id = GLOSSARIES.course
    LEFT OUTER JOIN (
    SELECT course, COUNT(id) as count FROM mdl_forum GROUP BY course 
    ) FORUMS ON mdl_course.id = FORUMS.course
    LEFT OUTER JOIN (
    SELECT course, COUNT(id) as count FROM mdl_chat GROUP BY course 
    ) CHATS ON mdl_course.id = CHATS.course
    LEFT OUTER JOIN (
    SELECT course, COUNT(id) as count FROM mdl_choice GROUP BY course 
    ) POLLS ON mdl_course.id = POLLS.course
    LEFT OUTER JOIN (
    SELECT course, COUNT(id) as count FROM mdl_feedback GROUP BY course 
) FEEDBACKS ON mdl_course.id = FEEDBACKS.course

###
### Resources Audit
###
LEFT OUTER JOIN (
    SELECT course, COUNT(id) as count FROM mdl_book GROUP BY course 
    ) BOOKS ON mdl_course.id = BOOKS.course
    LEFT OUTER JOIN (
    SELECT course, COUNT(id) as count FROM mdl_page GROUP BY course 
    ) PAGES ON mdl_course.id = PAGES.course
    LEFT OUTER JOIN (
    SELECT course, COUNT(id) as count FROM mdl_url GROUP BY course 
    ) URLS ON mdl_course.id = URLS.course
    LEFT OUTER JOIN (
    SELECT course, COUNT(id) as count FROM mdl_folder GROUP BY course 
    ) FOLDERS ON mdl_course.id = FOLDERS.course
    LEFT OUTER JOIN (
    SELECT course, COUNT(id) as count FROM mdl_resource GROUP BY course 
) RESOURCES ON mdl_course.id = RESOURCES.course

###
### Quiz Audit
###
LEFT OUTER JOIN ( 
    SELECT courseid, COUNT(id) as count 
    FROM mdl_grade_items WHERE itemmodule = 'quiz' 
    GROUP BY courseid 
) QUIZ ON mdl_course.id = QUIZ.courseid
LEFT OUTER JOIN (
    SELECT courseid, COUNT(*) as count FROM mdl_grade_grades 
    JOIN mdl_grade_items ON mdl_grade_grades.itemid = mdl_grade_items.id
    JOIN mdl_course ON mdl_course.id = mdl_grade_items.courseid
    WHERE 
    rawgrade IS NOT NULL
    AND itemmodule = 'quiz'
    # AND mdl_grade_grades.timemodified<1478476800
    GROUP BY courseid
) QGRADES ON mdl_course.id = QGRADES.courseid


###
### Activity Audit
###
JOIN
(
SELECT mdl_course.id, coalesce(LA.ActiveStudents,0) as Last7days, coalesce(LAM.ActiveStudents,0) as Last30Days, EU.Total as TotalStudents, coalesce(LA.ActiveStudents/EU.Total*100,0) Percent7Days, coalesce(LAM.ActiveStudents/EU.Total*100,0) Percent30Days FROM mdl_course
    
    ###
    ### Last 7 days
    ###
    LEFT JOIN
    (
        SELECT 
            ULA.courseid, COUNT(DISTINCT U.id) as ActiveStudents
        FROM mdl_user_lastaccess ULA
        JOIN mdl_user U ON U.id = ULA.userid
        JOIN mdl_user_info_data UID ON U.id = UID.userid AND UID.fieldid = 1
        WHERE 
            ULA.timeaccess > (UNIX_TIMESTAMP(NOW()) - 86400*7)
        AND UID.data = 'Student'
        GROUP BY ULA.courseid
    ) LA
    ON mdl_course.id = LA.courseid

    ###
    ### Last 30 days
    ###
    LEFT JOIN
    (
        SELECT 
            ULA.courseid, COUNT(DISTINCT U.id) as ActiveStudents
        FROM mdl_user_lastaccess ULA
        JOIN mdl_user U ON U.id = ULA.userid
        JOIN mdl_user_info_data UID ON U.id = UID.userid AND UID.fieldid = 1
        WHERE 
            ULA.timeaccess > (UNIX_TIMESTAMP(NOW()) - 86400*30)
        AND UID.data = 'Student'
        GROUP BY ULA.courseid
    ) LAM
    ON mdl_course.id = LAM.courseid

    ###
    ### Last quarter days
    ###
    LEFT JOIN (
        SELECT DISTINCT c.id as course, COALESCE(count(DISTINCT u.id),0) as Total
        FROM mdl_user u
        JOIN mdl_user_enrolments ue ON ue.userid = u.id
        JOIN mdl_enrol e ON e.id = ue.enrolid
        JOIN mdl_role_assignments ra ON ra.userid = u.id
        JOIN mdl_context ct ON ct.id = ra.contextid AND ct.contextlevel = 50
        JOIN mdl_course c ON c.id = ct.instanceid AND e.courseid = c.id
        WHERE e.status = 0 AND u.suspended = 0 AND u.deleted = 0
        AND (ue.timeend = 0 OR ue.timeend > NOW()) AND ue.status = 0
        AND ra.roleid = 5
        GROUP by c.id
    ) EU
ON mdl_course.id = EU.course
JOIN mdl_course_categories ON mdl_course.category = mdl_course_categories.id
) PC ON mdl_course.id = PC.id 

WHERE
    ###
    ### Add your custom filters here
    ###
    shortname LIKE '%18-19%'
    # path like '/?/?'
ORDER BY 
    shortname
