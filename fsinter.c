#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <lua5.3/lua.h>
#include <lua5.3/lauxlib.h>

#define setfield(field, valkind, val) \
  do {                                \
    lua_pushstring(L, (field));       \
    lua_push##valkind(L, (val));      \
    lua_settable(L, -3);              \
  } while (0)

static void lua_pushstat(lua_State *L, struct stat *stt) {
  lua_newtable(L);
#define setstatfield(name, kind) setfield("st_" #name, kind, stt->st_##name)
#if defined(_POSIX_C_SOURCE) && _POSIX_C_SOURCE >= 200809L
#define setts(name)                             \
  do {                                          \
    lua_newtable(L);                            \
    lua_pushinteger(L, 1);                      \
    lua_pushinteger(L, stt->st_##name.tv_sec);  \
    lua_settable(L, -3);                        \
    lua_pushinteger(L, 2);                      \
    lua_pushinteger(L, stt->st_##name.tv_nsec); \
    lua_settable(L, -3);                        \
  } while (0)
#else
#define setts(name)                             \
  do {                                          \
    lua_newtable(L);                            \
    lua_pushinteger(L, 1);                      \
    lua_pushinteger(L, stt->st_##name##e);      \
    lua_settable(L, -3);                        \
    lua_pushinteger(L, 2);                      \
    lua_pushinteger(L, 0);                      \
    lua_settable(L, -3);                        \
  } while (0)
#endif /* defined(_POSIX_C_SOURCE) && _POSIX_C_SOURCE >= 200809L */
  setstatfield(dev, integer);
  setstatfield(ino, integer);
  setstatfield(mode, integer);
  setstatfield(nlink, integer);
  setstatfield(uid, integer);
  setstatfield(gid, integer);
  setstatfield(rdev, integer);
  setstatfield(size, integer);
  setstatfield(blksize, integer);
  setstatfield(blocks, integer);
  lua_pushstring(L, "st_atim");
  setts(atim);
  lua_settable(L, -3);
  lua_pushstring(L, "st_mtim");
  setts(atim);
  lua_settable(L, -3);
  lua_pushstring(L, "st_ctim");
  setts(atim);
  lua_settable(L, -3);
#undef setstatfield
#undef setts
}

__attribute__((noinline))
static int l_stat(lua_State *L) {
  char const *path = luaL_checkstring(L, 1);
  struct stat stt;
  lua_pushinteger(L, stat(path, &stt));
  lua_pushstat(L, &stt);
  return 2;
}

__attribute__((noinline))
static int l_fstat(lua_State *L) {
  FILE *fp = (FILE *)lua_touserdata(L, 1);
  struct stat stt;
  lua_pushinteger(L, fstat(fileno(fp), &stt));
  lua_pushstat(L, &stt);
  return 2;
}

#if defined(_POSIX_C_SOURCE) && _POSIX_C_SOURCE >= 200809L
#define filetimefn(tt)                              \
  __attribute__((noinline))                         \
  static int l_##tt##time(lua_State *L) {           \
    char const *path = luaL_checkstring(L, 1);      \
    struct stat stt;                                \
    if (stat(path, &stt) == 0) {                    \
      lua_pushinteger(L, stt.st_##tt##tim.tv_sec);  \
      lua_pushinteger(L, stt.st_##tt##tim.tv_nsec); \
    } else {                                        \
      lua_pushinteger(L, -1);                       \
      lua_pushinteger(L, -1);                       \
    }                                               \
    return 2;                                       \
  }
#else
#define filetimefn(tt)                          \
  __attribute__((noinline))                     \
  static int l_##tt##time(lua_State *L) {       \
    char const *path = luaL_checkstring(L, 1);  \
    struct stat stt;                            \
    if (stat(path, &stt) == 0) {                \
      lua_pushinteger(L, stt.st_##tt##time);    \
      lua_pushinteger(L, 0);                    \
    } else {                                    \
      lua_pushinteger(L, -1);                   \
      lua_pushinteger(L, -1);                   \
    }                                           \
    return 2;                                   \
  }
#endif /* defined(_POSIX_C_SOURCE) && _POSIX_C_SOURCE >= 200809L */

filetimefn(a);
filetimefn(m);
filetimefn(c);

__attribute__((noinline))
extern int luaopen_fsinter(lua_State *L) {
  lua_newtable(L);

  lua_pushstring(L, "stat");
  lua_pushcfunction(L, l_stat);
  lua_settable(L, -3);

  lua_pushstring(L, "fstat");
  lua_pushcfunction(L, l_fstat);
  lua_settable(L, -3);

  lua_pushstring(L, "atime");
  lua_pushcfunction(L, l_atime);
  lua_settable(L, -3);

  lua_pushstring(L, "mtime");
  lua_pushcfunction(L, l_mtime);
  lua_settable(L, -3);

  lua_pushstring(L, "ctime");
  lua_pushcfunction(L, l_ctime);
  lua_settable(L, -3);
  return 1;
}
