class MountaineerGoatComponent extends GGMutatorComponent;

var GGGoat gMe;
var GGMutator myMut;

var CableRope mRope;

var GGCrosshairActor mCrosshairActor;
var Actor mTargetActor;
var float mAttachRadius;

var bool mIsFreeLook;

var SkeletalMeshComponent mBeardMesh;
var SkeletalMeshComponent mScarfMesh;// Scarf is freaking out when unfixed
var SoundCue mCableLinkSound;

/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=owningMutator;

		mBeardMesh.SetLightEnvironment( gMe.mesh.LightEnvironment );
		gMe.mesh.AttachComponentToSocket( mBeardMesh, 'ArmorHead' );
		mBeardMesh.WakeRigidBody();

		//mScarfMesh.SetLightEnvironment( gMe.mesh.LightEnvironment );
		//gMe.mesh.AttachComponentToSocket( mScarfMesh, 'ArmorShoulders' );

		//mScarfMesh.SetPhysicsAsset( mScarfMesh.PhysicsAsset );
		//mScarfMesh.WakeRigidBody();

		//gMe.SetTimer( 0.5f, false, nameOf( DelayUpdate ), self );
	}
}

function DetachFromPlayer()
{
	mCrosshairActor.DestroyCrosshair();
	super.DetachFromPlayer();
}

function DelayUpdate()
{
	local name boneName;

	boneName='joint2';
	mScarfMesh.PhysicsAssetInstance.ForceAllBodiesBelowUnfixed( boneName, mScarfMesh.PhysicsAsset, mScarfMesh, true );
}

function OnPlayerRespawn( PlayerController respawnController, bool died )
{
	super.OnPlayerRespawn( respawnController, died );

	if( respawnController.Pawn == gMe )
	{
		DelayUpdate();
	}
}

function TickMutatorComponent( float deltaTime )
{
	super.TickMutatorComponent( deltaTime );

	//Update crosshair
	if(mCrosshairActor == none || mCrosshairActor.bPendingDelete)
	{
		mCrosshairActor = gMe.Spawn(class'GGCrosshairActor');
	}
	mCrosshairActor.SetColor(IsValidAttach()?MakeLinearColor( 0.f, 1.f, 0.f, 1.0f ):MakeLinearColor( 1.f, 0.f, 0.f, 1.0f ));
	mCrosshairActor.SetHidden(!mIsFreeLook && mRope == none);
	UpdateCrosshair(GetStartLocation());
}

function bool IsValidAttach()
{
	return mTargetActor != none && mTargetActor.bStatic;
}

function vector GetStartLocation()
{
	local vector startLocation;

	gMe.mesh.GetSocketWorldLocationAndRotation( 'Demonic', startLocation );
	if(IsZero(startLocation))
	{
		startLocation=gMe.Location + (Normal(vector(gMe.Rotation)) * (gMe.GetCollisionRadius() + 30.f));
	}

	return startLocation;
}

function UpdateCrosshair(vector aimLocation)
{
	local vector			StartTrace, EndTrace, AdjustedAim, camLocation;
	local rotator 			camRotation;
	local Array<ImpactInfo>	ImpactList;
	local ImpactInfo 		RealImpact;
	local float 			Radius;

	if(gMe != None)
	{
		StartTrace = aimLocation;

		GGPlayerControllerGame( gMe.Controller ).PlayerCamera.GetCameraViewPoint( camLocation, camRotation );
		camRotation.Pitch+=1800.f;
		AdjustedAim = vector(camRotation);

		Radius = mCrosshairActor.SkeletalMeshComponent.SkeletalMesh.Bounds.SphereRadius;
		EndTrace = StartTrace + AdjustedAim * (mAttachRadius - Radius);

		RealImpact = CalcWeaponFire(StartTrace, EndTrace, ImpactList);

		mTargetActor = RealImpact.HitActor;
		mCrosshairActor.UpdateCrosshair(RealImpact.hitLocation, -AdjustedAim);
	}
}


simulated function ImpactInfo CalcWeaponFire(vector StartTrace, vector EndTrace, optional out array<ImpactInfo> ImpactList)
{
	local vector			HitLocation, HitNormal;
	local Actor				HitActor;
	local TraceHitInfo		HitInfo;
	local ImpactInfo		CurrentImpact;

	HitActor = CustomTrace(HitLocation, HitNormal, EndTrace, StartTrace, HitInfo);

	if( HitActor == None )
	{
		HitLocation	= EndTrace;
	}

	CurrentImpact.HitActor		= HitActor;
	CurrentImpact.HitLocation	= HitLocation;
	CurrentImpact.HitNormal		= HitNormal;
	CurrentImpact.RayDir		= Normal(EndTrace-StartTrace);
	CurrentImpact.StartTrace	= StartTrace;
	CurrentImpact.HitInfo		= HitInfo;

	ImpactList[ImpactList.Length] = CurrentImpact;

	return CurrentImpact;
}

function Actor CustomTrace(out vector HitLocation, out vector HitNormal, vector EndTrace, vector StartTrace, out TraceHitInfo HitInfo)
{
	local Actor hitActor, retActor;

	foreach gMe.TraceActors(class'Actor', hitActor, HitLocation, HitNormal, EndTrace, StartTrace, ,HitInfo)
    {
		if(hitActor != gMe
		&& hitActor.Owner != gMe
		&& hitActor.Base != gMe
		&& hitActor != gMe.mGrabbedItem
		&& !hitActor.bHidden)
		{
			//myMut.WorldInfo.Game.Broadcast(myMut, "actor hit=" $ hitActor $ ", hidden=" $ hitActor.bHidden);
			retActor=hitActor;
			break;
		}
    }

    return retActor;
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;

	if(PCOwner != gMe.Controller)
		return;

	localInput = GGPlayerInputGame( PCOwner.PlayerInput );

	if( keyState == KS_Down )
	{
		if( localInput.IsKeyIsPressed( "GBA_FreeLook", string( newKey ) ) )
		{
			mIsFreeLook = true;
		}

		if( localInput.IsKeyIsPressed( "GBA_AbilityBite", string( newKey ) ) )
		{
			TryAttachCable();
		}
	}
	else if( keyState == KS_Up )
	{
		if( localInput.IsKeyIsPressed( "GBA_FreeLook", string( newKey ) ) )
		{
			mIsFreeLook = false;
		}
	}
}

function TryAttachCable()
{
	// Don't link things while driving?
	if(mGoat.DrivenVehicle != None)
		return;

	if(mRope == none)
	{
		if(mIsFreeLook && IsValidAttach())
		{
			SpawnRope();
			gMe.PlaySound(mCableLinkSound);
		}
	}
	else
	{
		if(IsValidAttach())
		{
			mRope.FixRope(mRope.mLocation1, mCrosshairActor.Location);
			mRope = none;
			gMe.PlaySound(mCableLinkSound);
		}
		else if(mTargetActor == none)
		{
			mRope.BreakCable();
			mRope = none;
		}
	}
}

function SpawnRope()
{
	mRope = gMe.Spawn(class'CableRope',,, gMe.Location,,, true);
	mRope.AttachRope(none, mCrosshairActor, mCrosshairActor.Location, gMe.Location);
}

defaultproperties
{
	Begin Object class=SkeletalMeshComponent Name=SkeletalMeshComp1
		SkeletalMesh=SkeletalMesh'Goat_Zombie.mesh.GoatBeard'
		PhysicsAsset=PhysicsAsset'Goat_Zombie.Mesh.GoatBeard_Physics'
		scale = 2.f
		Translation=(X=10.f, Y=0.f, Z=10.f)
		bHasPhysicsAssetInstance=true
		bCacheAnimSequenceNodes=false
		AlwaysLoadOnClient=true
		AlwaysLoadOnServer=true
		bOwnerNoSee=false
		CastShadow=true
		BlockRigidBody=true
		CollideActors=true
		bUpdateSkelWhenNotRendered=false
		bIgnoreControllersWhenNotRendered=true
		bUpdateKinematicBonesFromAnimation=true
		bCastDynamicShadow=true
		RBChannel=RBCC_Untitled3
		RBCollideWithChannels=(Untitled1=false,Untitled2=false,Untitled3=true,Vehicle=true)
		bOverrideAttachmentOwnerVisibility=true
		bAcceptsDynamicDecals=false
		TickGroup=TG_PreAsyncWork
		MinDistFactorForKinematicUpdate=0.0
		bChartDistanceFactor=true
		RBDominanceGroup=15
		bSyncActorLocationToRootRigidBody=true
		bNotifyRigidBodyCollision=true
		ScriptRigidBodyCollisionThreshold=1
        BlockActors=TRUE
		AlwaysCheckCollision=TRUE
	End Object
	mBeardMesh=SkeletalMeshComp1

	//Begin Object class=SkeletalMeshComponent Name=SkeletalMeshComp2
	//	SkeletalMesh=SkeletalMesh'Goat_Zombie.Meshes.JourneyScarf'
	//	PhysicsAsset=PhysicsAsset'Goat_Zombie.Meshes.JourneyScarf_Physics'
	//	Materials(0)=Material'Goat_Zombie.Materials.JourneyScarf_Mat_01'
	//	bHasPhysicsAssetInstance=true
	//End Object
	//mScarfMesh=SkeletalMeshComp2

	mAttachRadius = 5000.f
	mCableLinkSound = SoundCue'Heist_Audio.Cue.SFX_Syringe_Shot_Mono_01_Cue'
}