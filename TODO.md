- [ ] Isolate client position, view box and dimension.
	- [x] draw avatar based on dimension.
	- [x] send dimension with avatar.
- [ ] Distinguish between client camera position, observer position and avatar position.
- [ ] Associate multiple clients with single view box.

- [ ] Optimize ray tracing. Do two level tracing. Get chunk, trace, then get next chunk. Will save time on getting chunk. Can skip uniform chunks.
- [ ] Add server options for autosave and autosave period.
- [ ] Detach worker threads so GC does not stop them.
- [x] fix problem with dimension change when old position confuses server and box is not updated.
	(Use position key. Client sends key with current position. Server only accepts positions with current key. Client and server increment position key when position changes)
- [x] Add client view radius config option.
- [x] Fix WorldBox equality checking.
- [x] Generic Box type

----
### UI
- [ ] Autocomplete in console
- [ ] Translation strings.
- [ ] Launcher nick option/
- [ ] Launcher menu for world conversion tool/

----
### GRAPHICS
- [ ] Add configurable meshing range.
- [ ] Remove meshes outside of mesh range.
- [ ] Implement command buffer for rendering. All rendering commands are recorded into buffer, then pipeline object renders everything. Possibly in another thread. RenderIR.
- [ ] Implement chunk mesh preloading for all meshes.
- [ ] Redo chunk block metadata. Metadata should simply state if chunk has internal geometry and side solidities.
- [ ] Populate lookup chunk with block shape data before meshing.
- [x] Implement blockShapeHandler for block entities.
- [x] Fix side intersection table size.
- [x] Fix rendering of blocks adjacent to water.
- [x] Finish new rendering code.
- [U] Upload meshes in worker threads. Avoid copy of mesh. / Undone. Rendering issues.
- [x] Implement per corner solidity.
- [x] Implement block side masks.
- [x] Implement block shapes.
- [x] Implement optimized mesh generation.
- [x] Implement ambient occlusion
- [x] Implement chunk mesh preloading. (Only meshes of current meshing pass is preloaded).
- [x] Replace arrays and Appenders with Buffers in Batch and meshing.
- [x] Use half-floats for chunk meshes.
- [x] Make generic vertex.

----
### RAILROAD
- [ ] Separate stub meshes and read adjacent rails for advanced meshing.
- [x] Use stone/gravel material for rail's bottom side and for slope's side.
- [x] Click-and-drag rail placement.
- [x] Improve rail solidity check. Use bitmaps to get solidity info for each rail segment.
- [x] Multiple rails per tile.
- [x] Add mesh rotation.
- [x] Add rail mesh based on rail type.
- [x] Store rail type in entity data.
- [x] Make rail bounding box fit to mesh.
- [x] Load and render rail mesh.

----
### STORAGE
- [ ] Improve calculation of modified chunks.
- [x] Fix component id sync
- [ ] BUG: In chunk manager when layer has users, buffer allocated for uncompressed data is never freed.
- [ ] BUG: In chunk manager returned pointer points inside hash table. If new write buffer is added hash table can reallocate. Do not use more than one write buffer at a time.
Reallocation can prevent changes to buffers obtained earlier than reallocation to be invisible.
- [ ] Use regions to store number of chunk users. This can help boost user add/removal, if chunks will store their user count in a region table.
- [ ] Move metadata update on commit stage. Useful when multiple changes per frame occur to a chunk. Metadata update can be done in parallel.
- [ ] Add storage for uncompressed layer data in chunk manager. Compressed data can be stored along with decompressed.
- [ ] Remove BlockData. First ChunkLayerSnap needs custom (de)serizalizer due to union usage.
- [x] Do not uncompress unneeded chunks (non-visible). Decide by metadata.
- [x] Do not uncompress chunks on client until requested.
- [x] Implement heightmap caching in chunk gen.

----
### BLOCK ENTITIES
- [x] Add block entity rendering.
- [x] Fix write buffer retrieval. Old snapshot was copied every time, not only when WB was created.
- [x] Use block entity mesh handlers for meshing.
- [x] Send block entity layer to mesh workers.
- [x] Multichunk block entity.
- [x] Add block entity removing.
- [x] Add block entity type registry.
- [x] Send block entity layer to client.
- [x] Add block entity code.
- [x] Add static entity layer code.

----
### ENTITIES

- [x] Send only observed entities.

----
### EDITING


----
### OTHER

- [x] Use metadata in slope block.
- [x] Add block metadata layer.
- [x] Fill slope rail sides with faces when not occluded.
- [x] Move chunk debug info gui into clientworld.
- [x] Add block rotation handler.
- [x] Add extra slope side shapes.
- [x] Add ShapeMetaHandler.
- [x] Fix AO flipped quad meshing.
- [x] Fix non-existing chunk layers being sent to client (Chunk manager always returns empty snapshot when chunk is loaded).
- [x] Add ChunkLayerInfo.
- [x] Add hasSnapshot to chunk manager.
- [x] Fix chunk manager returning layers with wrong data length for uniform chunks.
- [x] Allow any vertex type being put in batch.
- [x] 2d rendering
- [x] Correctly handle clients with the same name.
- [x] Minecraft save import
- [x] Implement launcher server connection feature.
- [x] for each layer universal handlers for allocation, save, load, write buffer. Some layers may not have data even when chunk is loaded.
- [x] remove _saving states in chunk manager
- [x] Fix case in chunk manager when old snapshot was saved and current snapshot is added_loaded.
- [x] Toolbar.
- [x] Restore capture of per-block changes.
- [x] Add active chunk system.
- [x] Fix app not stopping when main thread crashes.
- [x] Implement generic solution for saving/loading data for use in plugins.
	(double buffering?)
	- [x] Fix world save on game stop.
- [x] Complex write buffer with delayed allocation and uniform type support.
- [x] Big-scale editing. Send edit commands instead of per-block changes.
- [x] Fix mesh deletion when chunk does not produce mesh. Use special "delete mesh" tasks to queue mesh deletions. This allows to upload new chunk meshes together with deleting meshes of chunks that do not produce meshes anymore.
- [x] fix chunks not loading sometimes [Chunks were not added early enough, so first snapshots were loaded for not added chunks => holes]
- [x] remove old observer on client when (re)connecting
- [x] fix metadata usage in chunk mesh manager. [Bug in hasSingleSolidity]
- [x] fix crash on recieving data for already loaded chunks. [isLoaded was not checked. Now chunks are loaded through modification]
- [x] fix snapshot users not correctly added on commit. [snapshot was added to oldSnapshots with wrong timestamp (currentTime instead of snap.timestamp)]
- [x] change clientworld
- [x] remove chunkman
- [x] remove chunkstorage
- [x] chunkmanager usage of chunkProvider
- [x] rework chunkmeshman
- [x] mesh gen new queue
- [x] remove observer on stop in client
- [x] set received data in chunk manager on client
- [x] remove chunk changes from chunk manager
- [x] remove mesh when mesh is not generated on remesh
- [x] remove limit on message size in shared queue
- [x] remove chunk
- [x] add remesh button
- [x] fix memory leak. Meshes was iterated by value and was loaded each frame again. Fix: change foreach(mesh) to foreach(ref mesh)
- [x] fix transparent drawing
- [x] implement total number of snapshot users
- [x] fix excess addCurrentSnapshotUser call on save in onSnapshotLoaded (chunks were not unloaded earlier?)