-- 查询锁命令. 锁类型 AccessShareLock, RowShareLock, RowExclusiveLock, ShareUpdateExclusiveLock, ShareLock, ShareRowExclusiveLock, ExclusiveLock, AccessExclusiveLock

select
	a.locktype,
	a.database,
	a.mode,
	a.relation,
	b.relname
from
	pg_locks a
join pg_class b on
	a.relation = b.oid
where
	lower(a.mode) in ('rowexclusivelock',
	'shareupdateexclusivelock',
	'sharerowexclusivelock',
	'exclusivelock',
	'accessexclusivelock')
	-- ,'accesssharelock')
