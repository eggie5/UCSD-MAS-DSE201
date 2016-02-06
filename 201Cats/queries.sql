-- 1) Option “Overall Likes”: The Top-10 cat videos are the ones that have collected the highest numbers of likes, overall.
select video.video_id, video.video_name, count(video.video_id) as count from cats.video
join cats.likes on likes.video_id = video.video_id
group by video.video_id
order by count desc
limit 10


-- 2) Option “Friend Likes”: The Top-10 cat videos are the ones that have collected the highest numbers of likes from the friends of X.
select video.video_id, video.video_name, count(video.video_id) as count from cats.video
join cats.likes on likes.video_id = video.video_id
join cats.friend on likes.user_id = friend.friend_id
where friend.user_id=1
group by video.video_id
order by count desc
limit 10




-- Option “Friends-of-Friends Likes”: The Top-10 cat videos are the ones that have collected the highest numbers of likes from friends and friends-of-friends.
WITH fof AS(
SELECT friend.user_id, friend.friend_id
FROM cats.friend 
join cats.user on cats.user.user_id = friend.friend_id
WHERE friend.user_id = 1

UNION 

SELECT fof.user_id, fof.friend_id
FROM cats.friend friends, cats.friend fof
join cats.user on cats.user.user_id = fof.friend_id
WHERE friends.friend_id = fof.user_id
 AND friends.user_id =1

order by user_id
)

select  video.video_id, video.video_name, count(DISTINCT likes.like_id) as count 
from cats.video
join cats.likes on likes.video_id = video.video_id
join fof on fof.friend_id = likes.user_id
group by video.video_id
order by count desc
limit 10


-- Option “My kind of cats”: The Top-10 cat videos are the ones that have collected the most likes from users who have liked at least one cat video that was liked by X.

with my_likes as (select likes.video_id from cats.likes where likes.user_id=1)

select likes.video_id, COUNT(likes.video_id)
from cats.likes, my_likes
where likes.video_id IN (my_likes.video_id) AND user_id !=1
group by likes.video_id
limit 10



--- weighted likes

with wt_likes as(
select user_id, log(1+count(like_id)) as weight
from cats.likes
where video_id in(select video_id from cats.likes where user_id=1)
and user_id != 790
group by user_id)

select l.video_id, v.video_name, coalesce(sum(wt_likes.weight),0)
from cats.likes l
left join wt_likes on wt_likes.user_id=l.user_id
left join cats.video v on l.video_id = v.video_id
group by 1,2 
order by coalesce(sum(wt_likes.weight),0)desc
limit 10