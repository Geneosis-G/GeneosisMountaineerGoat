class CableRope extends DynamicSMActor;

var Actor mActor1;
var Actor mActor2;

var vector mLocation1;
var vector mLocation2;

var bool mIsAttached;
var bool mIsFixed;
var bool mIsBroken;
var float mDefaultLength;
var float mRopeScaleFactor;

event PostBeginPlay()
{
	local float r;

	super.PostBeginPlay();

	SetRotation(rot(0, 0, 0));
	GetBoundingCylinder(r, mDefaultLength);

	SetCollision(false, false);
	SetCollisionType(COLLIDE_NoCollision);
	CollisionComponent.SetActorCollision(false, false);
	CollisionComponent.SetBlockRigidBody(false);
	CollisionComponent.SetNotifyRigidBodyCollision(false);
}

/**
 * Connects two primitive components with the rope, this won't work very well if distance between location1 and location2 is too long
 */
function AttachRope(Actor act1, Actor act2, vector location1, vector location2)
{
	mActor1 = act1;
	mActor2 = act2;

	mLocation1 = location1;
	mLocation2 = location2;

	mIsAttached = true;
}

function FixRope(vector location1, vector location2)
{
	mActor1 = none;
	mActor2 = none;

	mLocation1 = location1;
	mLocation2 = location2;

	//WorldInfo.Game.Broadcast(self, "AttachRope(" $ mComp1 $ "," $ mComp2 $ "," $ mLocation1 $ "," $ mLocation2 $ "," $ mBone1 $ "," $ mBone2 $ ")");
	UpdateRopeLocation();
	mIsFixed = true;

	SetCollision(true, true);
	SetCollisionType(COLLIDE_BlockAll);
	CollisionComponent.SetActorCollision(true, true);
	CollisionComponent.SetBlockRigidBody(true);
	CollisionComponent.SetNotifyRigidBodyCollision(true);
}

function DetachRope()
{
	mIsAttached = false;
	mIsFixed = false;
}

function BreakCable()
{
	if(!mIsBroken)
	{
		mIsBroken = true;
		ShutDown();
		Destroy();
	}
}

event Tick(float deltaTime)
{
	super.Tick(DeltaTime);

	SetPhysics(PHYS_None);
	UpdateRopeLocation();
}

function UpdateRopeLocation()
{
	local vector location1, location2, betweenLocations;
	local float scaleFactor;

	if(!mIsAttached || mIsFixed)
		return;

	if(mActor1 != none)
	{
		location1 = mActor1.Location;
	}
	if(location1 == vect(0, 0, 0))
	{
		location1 = mLocation1;
	}

	if(mActor2 != none)
	{
		location2 = mActor2.Location;
	}
	if(location2 == vect(0, 0, 0))
	{
		location2 = mLocation2;
	}

	// Convert lenght into rope scale
	betweenLocations = location2 - location1;
	scaleFactor = mRopeScaleFactor * VSize(betweenLocations) / mDefaultLength;
	StaticMeshComponent.SetScale3D(vect(1.f, 1.f, 0.f) + (vect(0.f, 0.f, 1.f) * scaleFactor));
	// Place rope between locations
	SetLocation(location2);
	SetRotation(rotator(normal(betweenLocations)) + rot(16384, 0, 0));
	//WorldInfo.Game.Broadcast(self, "================");
	//WorldInfo.Game.Broadcast(self, "location1=" $ location1);
	//WorldInfo.Game.Broadcast(self, "location2=" $ location2);
	//WorldInfo.Game.Broadcast(self, "ropeLocation=" $ ropeLocation);
	//WorldInfo.Game.Broadcast(self, "VSize(betweenLocations)=" $ VSize(betweenLocations));
	//WorldInfo.Game.Broadcast(self, "mDefaultLength=" $ mDefaultLength);
	//WorldInfo.Game.Broadcast(self, "scaleFactor=" $ scaleFactor);
}

simulated event TakeDamage( int damage, Controller eventInstigator, vector hitLocation, vector momentum, class< DamageType > damageType, optional TraceHitInfo hitInfo, optional Actor damageCauser )
{
	super.TakeDamage(damage, eventInstigator, hitLocation, momentum, damageType, hitInfo, damageCauser);

	//WorldInfo.Game.Broadcast(self, "TakeDamage type=" $ damageType);
	if(class< GGDamageTypeAbility >(damageType) != none || class< GGDamageTypeExplosiveActor >(damageType) != none)
    {
        BreakCable();
    }
}

DefaultProperties
{
	mRopeScaleFactor = 0.506f;

	Begin Object name=StaticMeshComponent0
		StaticMesh=StaticMesh'Space_ObstacleCourse.Meshes.Rope'
		Scale3D=(X=1.f,Y=1.f,Z=1.f)
		bNotifyRigidBodyCollision=true
		ScriptRigidBodyCollisionThreshold=1.0f //if too big, we won't get any notifications from collisions between kactors
		CollideActors=true
		BlockActors=true
		BlockZeroExtent=true
		BlockNonZeroExtent=true
	End Object
	CollisionComponent=StaticMeshComponent0

	bNoDelete=false
	bStatic=false
}