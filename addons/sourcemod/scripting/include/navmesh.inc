#if defined _navmesh_included
	#endinput
#endif
#define _navmesh_included

#define INVALID_NAV_AREA view_as<CNavArea>(-1)
#define NAV_MESH_WALK (1 << 0)
#define NAV_MESH_RUN (1 << 1)

methodmap CNavArea < Handle
{
}

native CNavArea NavMesh_GetNearestArea(const float pos[3], bool anyZ=false, float maxDist=10000.0, bool checkLOS=false, bool checkGround=true, int team=-2);
native bool NavMesh_GetGroundHeight(const float pos[3], float &height);
native int NavMeshArea_GetFlags(CNavArea area);
