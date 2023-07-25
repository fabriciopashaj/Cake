local fsinter_path = package.searchpath(
   "cake/fsinter",
   package.cpath..";"..package.path)
local fsinter = package.loadlib(fsinter_path, "luaopen_fsinter")()

-- XXX: UNSTABLE & WIP

local _M = {}

local function joinpath(...)
   local joined_path = table.concat({...}, "/")
   return joined_path:gsub("([^.])?%./", "%1/"):gsub("/+", "/")
end

function _M.base_config()
   return {
      paths = {
         source = {},
         include = {},
         library = {},
         objects = {},
         build = "build"
      },
      compiler = {
         cc = {
            exe = "gcc",
            flags = ""
         },
         cxx = {
            exec = "g++",
            flags = ""
         }
      },
      linker = {
         exe = "gcc",
         libraries = {},
         flags = ""
      },
      hooks = {
         after_build = nil,
      }
   }
end

function _M.update_config(current, update)
   for key, val in pairs(update) do
      if type(current[key]) == "table" and type(val) == "table" then
         _M.update_config(current[key], val)
      else
         current[key] = val
      end
   end
end

local line = string.rep("-", 80)

local function exit_from_error()
   error("Exiting due to previous error")
end

local function isabs(path)
   return path:match("^/") ~= nil
end

local function print_command(cmd)
   print(line)
   print(cmd)
   print(line)
end

-- XXX: The 4 following functions can be unified into one
local function prepare_includes(project_dir, include_paths)
   local flags = {"-I'"..joinpath(project_dir, "cake_libs").."'"}
   for _, include_path in ipairs(include_paths) do
      if not isabs(include_path) then
         include_path = joinpath(project_dir, include_path)
      end
      if type(include_path) == "table" then
         print("HOLY SHIT WHAT IS A TABLE DOING HERE")
         print_table(include_path)
      end
      table.insert(flags, "-I'"..include_path.."'")
   end
   return table.concat(flags, " ")
end

local function prepare_libpaths(project_dir, libs_paths)
   local flags = {}
   for _, libs_path in ipairs(libs_paths) do
      if not isabs(libs_path) then
         libs_path = joinpath(project_dir, libs_path)
      end
      table.insert(flags, "-L'"..libs_path.."'")
   end
   return table.concat(flags, " ")
end

local function prepare_libs(project_dir, libs)
   local flags = {}
   for _, lib in ipairs(libs) do
      table.insert(flags, "-l'"..lib.."'")
   end
   return table.concat(flags, " ")
end

local function prepare_extra_objs(project_dir, obj_paths)
   local flags = {}
   for _, obj_path in ipairs(libs_paths) do
      if not isabs(obj_path) then
         lib_path = joinpath(project_dir, obj_path)
      end
      table.insert(flags, "'"..obj_path.."'")
   end
   return table.concat(flags, " ")
end

local function print_table(tbl)
   for k,v in pairs(tbl) do print(k,v) end
end

function _M.build_objects(project_dir, config)
   local build_dir = joinpath(project_dir, config.paths.build)
   local include_flags = prepare_includes(project_dir, config.paths.include)
   local object_files = {}
   for _, source_path in ipairs(config.paths.source) do
      local full_path = joinpath(project_dir, source_path)
      local obj_path = joinpath(build_dir, "obj", source_path..".o")
      local src_time, _ = fsinter.mtime(full_path)
      local obj_time, _ = fsinter.mtime(obj_path)
      if src_time == -1 then
         error("File \""..full_path.."\" doesn't exist")
      end
      if obj_time == -1 or src_time > obj_time then
         local comp_exe
         local extra_flags
         if source_path:match(".*(%..*)") == ".c" then
            comp_exe = config.compiler.cc.exe
            extra_flags = config.compiler.cc.flags
         else
            comp_exe = config.compiler.cxx.exe
            extra_flags = config.compiler.cxx.flags
         end
         -- TODO: Optimize the formatting
         local cmd = string.format("%s -o '%s' -c '%s' %s %s",
            comp_exe,
            obj_path,
            full_path,
            include_flags,
            extra_flags)
         print_command(cmd)
         local _, _, status = os.execute(cmd)
         if status ~= 0 then exit_from_error() end
         table.insert(object_files, obj_path)
      end
   end
   return object_files
end

function _M.link_objects(project_dir, config, object_files)
   local build_dir = joinpath(project_dir, config.paths.build)
   local libpath_flags = prepare_libpaths(project_dir, config.paths.library)
   local lib_flags = prepare_libs(project_dir, config.linker.libraries)
   local output_name = config.output or project_dir:match("^.*/[^/]*$")
   local output_path = joinpath(build_dir, "bin", output_name)
   local obj_files = table.concat(object_files, " ")
   local obj_time = -1
   for _, obj_file in ipairs(object_files) do
      local tv_sec, _ = fsinter.mtime(obj_file)
      if tv_sec > obj_time then obj_time = tv_sec end
   end
   local bin_time, _ = fsinter.mtime(output_path)
   if bin_time == -1 or obj_time > bin_time then
      -- local extra_objs = prepare_extra_objs(
      --    project_dir,
      --    config.paths.objects)
      local cmd = table.concat({
         config.linker.exe,
         "-o",
         output_path,
         obj_files,
         -- extra_objs,
         libpath_flags,
         lib_flags,
         config.linker.flags,
      }, " ")
      print_command(cmd)
      local _, _, status = os.execute(cmd)
      if status ~= 0 then exit_from_error() end
      -- TODO: Refine the hook system
      if config.hooks.after_build then config.hooks.after_build() end
   end
end

function _M.build_project(project_dir, config)
   local build_dir = joinpath(project_dir, config.paths.build)
   local object_files = _M.build_objects(project_dir, config)
   _M.link_objects(project_dir, config, object_files)
end

function _M.clean_build(project_dir, config)
   local build_dir = joinpath(project_dir, "build")
   os.execute(
      string.format("rm -f %s/obj/**/*.o %s/bin/*", build_dir, build_dir))
end

return _M
