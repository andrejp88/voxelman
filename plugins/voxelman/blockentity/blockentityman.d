/**
Copyright: Copyright (c) 2017 Andrey Penechko.
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/
module voxelman.blockentity.blockentityman;

import pluginlib;
import voxelman.math;
import voxelman.utils.mapping;
import voxelman.world.blockentity;

final class BlockEntityManager : IResourceManager
{
package:
	Mapping!BlockEntityInfo blockEntityMapping;

public:
	override string id() @property { return "voxelman.blockentity.blockentitymanager"; }

	BlockEntityInfoSetter regBlockEntity(string name) {
		size_t id = blockEntityMapping.put(BlockEntityInfo(name));
		assert(id <= ushort.max);
		return BlockEntityInfoSetter(&blockEntityMapping, id);
	}

	ushort getId(string name) {
		return cast(ushort)blockEntityMapping.id(name);
	}
}

struct BlockEntityInfoSetter
{
	private Mapping!(BlockEntityInfo)* mapping;
	private size_t blockId;
	private ref BlockEntityInfo info() {return (*mapping)[blockId]; }

	ref BlockEntityInfoSetter color(ubyte[3] color ...) { info.color = ubvec3(color); return this; }
	ref BlockEntityInfoSetter colorHex(uint hex) { info.color = ubvec3((hex>>16)&0xFF,(hex>>8)&0xFF,hex&0xFF); return this; }
	ref BlockEntityInfoSetter meshHandler(BlockEntityMeshhandler val) { info.meshHandler = val; return this; }
	ref BlockEntityInfoSetter sideSolidity(SolidityHandler val) { info.sideSolidity = val; return this; }
	ref BlockEntityInfoSetter blockShapeHandler(BlockShapeHandler val) { info.blockShape = val; return this; }
	ref BlockEntityInfoSetter boxHandler(EntityBoxHandler val) { info.boxHandler = val; return this; }
	ref BlockEntityInfoSetter debugHandler(EntityDebugHandler val) { info.debugHandler = val; return this; }
}
