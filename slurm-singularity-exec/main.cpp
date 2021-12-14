/*{{{
    Copyright © 2020 GSI Helmholtzzentrum fuer Schwerionenforschung GmbH
                     Matthias Kretz <m.kretz@gsi.de>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

}}}*/

#include <cstring>
#include <exception>
#include <optional>
#include <string>
#include <string_view>
#include <unistd.h>
#include <utility>
#include <vector>

extern "C"
{ // SPANK include
#include "spank.h"
}

/// string_view::starts_with replacement
bool
starts_with(const std::string_view& s, const std::string_view& prefix)
{
  if (prefix.length() > s.length())
    return false;
  else
    return prefix == s.substr(0, prefix.length());
}

/**
 * A type to wrap (argc, argv) into a proper container.
 */
class ArgumentVector : public std::vector<std::string_view>
{
public:
  ArgumentVector(const int n, char* args[])
  {
    reserve(n);
    for (int i = 0; i < n; ++i)
      emplace_back(args[i]);
  }
};

/**
 * A C++ wrapper for the SPANK API.
 */
class Buttocks
{
  spank_t handle;

  static void
  throw_on_error(spank_err_t err)
  {
    if (err != ESPANK_SUCCESS)
      throw SpankError(err);
  }

public:
  Buttocks(spank_t s) : handle(s) {}

  class InvalidHandle : public std::exception
  {
  public:
    const char*
    what() const noexcept override
    {
      return "invalid spank_t handle";
    }
  };

  class SpankError : public std::exception
  {
    const spank_err_t errcode;

  public:
    SpankError(spank_err_t err) : errcode(err) {}

    spank_err_t
    code() const noexcept
    {
      return errcode;
    }

    const char*
    what() const noexcept override
    {
      return spank_strerror(errcode);
    }
  };

  /// Return whether the plugin is in a remote context
  bool
  is_remote() const
  {
    int r = spank_remote(handle);
    if (r < 0)
      throw InvalidHandle{};
    return r == 1;
  }

  /// Return the context, where the code is currently executing
  static spank_context_t
  context()
  {
    spank_context_t c = spank_context();
    if (c == S_CTX_ERROR)
      throw SpankError(ESPANK_ERROR);
    return c;
  }

  /// Return job arguments as (count, array of c strings) pair
  std::pair<int, char**>
  job_arguments() const
  {
    std::pair<int, char**> job = { 0, nullptr };
    throw_on_error(
        spank_get_item(handle, S_JOB_ARGV, &job.first, &job.second));
    return job;
  }

  /// Return job arguments as std::vector<c string>
  std::vector<char*>
  job_argument_vector() const
  {
    auto [n, args] = job_arguments();
    std::vector<char*> r;
    r.reserve(n);
    for (int i = 0; i < n; ++i)
      r.push_back(args[i]);
    return r;
  }

  /// Return all environment variables
  char**
  job_env() const
  {
    char** job_env;
    throw_on_error(spank_get_item(handle, S_JOB_ENV, &job_env));
    return job_env;
  }

  /// Get environment variable
  std::optional<std::string>
  getenv(const char* var)
  {
    constexpr int size = 1024;
    char buf[size];
    auto err = spank_getenv(handle, var, buf, size);
    if (err == ESPANK_ENV_NOEXIST)
      return std::nullopt;
    throw_on_error(err);
    return buf;
  }

  /// Set environment variable
  void
  setenv(const char* var, const char* val)
  {
    throw_on_error(spank_setenv(handle, var, val, 1));
  }

  /// Add option without argument to srun/sbatch
  void
  register_switch(const char* name, const char* usage, int val,
                  spank_opt_cb_f callback)
  {
    spank_option opt{ const_cast<char*>(name),
                      nullptr,
                      const_cast<char*>(usage),
                      false,
                      val,
                      callback };
    throw_on_error(spank_option_register(handle, &opt));
  }

  /// Add option with argument to srun/sbatch
  void
  register_option(const char* name, const char* arginfo, const char* usage,
                  int val, spank_opt_cb_f callback)
  {
    spank_option opt{ const_cast<char*>(name),
                      const_cast<char*>(arginfo),
                      const_cast<char*>(usage),
                      true,
                      val,
                      callback };
    throw_on_error(spank_option_register(handle, &opt));
  }
};

/**
 * The singularity-exec plugin.
 */
struct singularity_exec
{
  inline static std::string s_container_name = {};
  inline static std::string s_container_path = {};
  inline static std::string s_singularity_script = "/usr/lib/slurm/slurm-singularity-wrapper.sh";
  inline static std::string s_singularity_args = {};
  inline static std::string s_bind_defaults = {};
  inline static std::string s_bind_mounts = {};
  inline static bool s_no_args_option = false;
  inline static bool s_default_container = true;
  inline static bool s_default_container_path = true;

  template <typename F0, typename F1>
  static int
  only_once(F0&& on_error, F1&& on_success)
  {
    static bool already_called = false;
    if (already_called)
      {
        if (Buttocks::context() == S_CTX_REMOTE)
          return 0;
        on_error();
        return -1;
      }
    already_called = true;
    if constexpr (std::is_same_v<decltype(on_success()), void>)
      {
        on_success();
        return 0;
      }
    else
      return on_success();
  }

  /// Set container name from --singularity-container
  static int
  set_container_name(int, const char* optarg, int)
  {
    return only_once(
        [&] {
          slurm_error("--singularity-container may not be set twice. It was "
                      "first set to '%s', then to '%s'.",
                      s_container_name.c_str(), optarg);
        },
        [&] {
          s_container_name = optarg;
          s_default_container = false;
        });
  }

  static int
  set_container_path(int, const char* optarg, int)
  {
    return only_once(
        [&] {
          slurm_error("--singularity-container-path may not be set twice. It was "
                      "first set to '%s', then to '%s'.",
                      s_container_path.c_str(), optarg);
        },
        [&] {
          s_container_path = optarg;
	  s_container_name = s_container_path+"/"+s_container_name;
          s_default_container_path = false;
        });
  }


  /// Add bind mount arguments from --singularity-bind
  static int
  add_bind_mounts(int, const char* optarg, int)
  {
    return only_once(
        [&] {
          slurm_error("--singularity-bind may not be set twice. It was first "
                      "set to '%s', then to '%s'.",
                      s_bind_mounts.c_str(), optarg);
        },
        [&] {
          s_bind_mounts = optarg;
#if 0
          if (s_bind_mounts.find(' ') != std::string::npos)
            {
              slurm_error("The argument to --singularity-bind may not contain "
                          "spaces.");
              return -1;
            }
          return 0;
#endif
        });
  }

  /// Disable default bind mounts
  static int
  disable_bind_defaults(int, const char*, int)
  {
    s_bind_defaults = {};
    return 0;
  }

  /// Set singularity arguments from --singularity-args
  static int
  set_singularity_args(int, const char* optarg, int)
  {
    return only_once(
        [&] {
          slurm_error("--singularity-args may not be set twice. It was first "
                      "set to '%s', then to '%s'.",
                      s_singularity_args.c_str(), optarg);
        },
        [&] { s_singularity_args = optarg; });
  }

  /// Initialize the plugin: read plugstack.conf config & register options
  static int
  init(Buttocks s, const ArgumentVector& args)
  {
    try
      {
        bool in_args = false;
        for (std::string_view arg : args)
          {
            slurm_debug("singularity-exec argument: %s", arg.data());
            if (in_args)
              {
                if (arg.back() == '"')
                  {
                    in_args = false;
                    arg.remove_suffix(1);
                  }
                (s_singularity_args += ' ') += arg;
              }
            else if (starts_with(arg, "default="))
              s_container_name = arg.substr(8);
            else if (starts_with(arg, "script="))
              s_singularity_script = arg.substr(7);
            else if (starts_with(arg, "bind="))
              s_bind_defaults = arg.substr(5);
	    else if (starts_with(arg, "path="))
	      s_container_path = arg.substr(5);
            else if (arg == "args=disabled")
              s_no_args_option = true;
            else if (starts_with(arg, "args=\""))
              {
                arg.remove_prefix(6);
                if (arg.back() == '"')
                  arg.remove_suffix(1);
                else
                  in_args = true;
                s_singularity_args = arg;
              }
            else
              slurm_error(
                  "singularity-exec plugin: argument in plugstack.conf is "
                  "invalid: '%s'. Supported arguments:\n"
                  "default=<container name>      may be empty\n"
                  "script=<path to executable>   defaults to "
                  "/usr/lib/slurm/slurm-singularity-wrapper.sh\n"
                  "bind=src[:dest[:opts]][,src[:dest[:opts]]]*\n"
                  "                              set default bind mounts\n"
		  "path=/path/to/container       sets path where container is stored"
                  "args=disabled                 Disable custom arguments\n"
                  "args=\"<singulary args>\"       quotes are mandatory; "
                  "string may be empty\n",
                  arg.data());
          }

        s.register_option(
            "singularity-container", "<name>",
            ("name of the requested container / user space (default: '" + s_container_name
             + "'); the environment variable SLURM_SINGULARITY_CONTAINER overwrites the default")
                .c_str(),
            0, set_container_name);

	s.register_option(
            "singularity-container-path", "<name>",
            ("path where the container is stored (default: '" + s_container_path
             + "'); the environment variable SLURM_SINGULARITY_CONTAINER_PATH overwrites the default")
                .c_str(),
            0, set_container_path);

        s.register_option(
            "singularity-bind", "spec",
            "a user-bind path specification.  spec has the format "
            "src[:dest[:opts]], where src and dest are outside and inside "
            "paths.  If dest is not given, it is set equal to src. Mount "
            "options ('opts') may be specified as 'ro' (read-only) or 'rw' "
            "(read/write, which is the default). Multiple bind paths can be "
            "given by a comma separated list. The environment variable "
            "SLURM_SINGULARITY_BIND can be used instead of this option.",
            0, add_bind_mounts);

        s.register_switch(
            "singularity-no-bind-defaults",
            ("disable bind mount defaults (default: " + s_bind_defaults + ")")
                .c_str(),
            0, disable_bind_defaults);

        if(!s_no_args_option)
          s.register_option(
              "singularity-args", "<args>",
              ("arguments to pass to singularity when containerizing "
               "the job (default: '"
               + s_singularity_args + "')")
                  .c_str(),
              0, set_singularity_args);

        return 0;
      }
    catch (const Buttocks::SpankError& err)
      {
        slurm_error("singularity-exec error: %s", err.what());
        return -err.code();
      }
  }

  /// execvpe the s_singularity_script for the job
  static int
  start_container(Buttocks s, const ArgumentVector&)
  {
    try
      {
        if (s_default_container)
          { // check SLURM_SINGULARITY_CONTAINER env var
            auto env = s.getenv("SLURM_SINGULARITY_CONTAINER");
            if (env)
              s_container_name = std::move(env).value();
          }
        if (s_container_name.empty() || s_singularity_script.empty())
          {
            slurm_verbose("singularity-exec: no container selected. Skipping "
                          "start_container.");
            return 0;
          }

        if (s_default_container_path)
          { // check SLURM_SINGULARITY_CONTAINER_PATH env var
            auto env = s.getenv("SLURM_SINGULARITY_CONTAINER_PATH");
            if (env)
              s_container_path = std::move(env).value();
	      s_container_name = s_container_path+"/"+s_container_name;
          }
        if (s_container_path.empty() || s_singularity_script.empty())
          {
            slurm_verbose("singularity-exec: no container selected. Skipping "
                          "start_container.");
            return 0;
          }


	if (s_bind_mounts.empty())
          {
            auto env = s.getenv("SLURM_SINGULARITY_BIND");
            if (env)
              s_bind_mounts = std::move(env).value();
          }
        if (!s_bind_defaults.empty())
          {
            if (s_bind_mounts.empty())
              s_bind_mounts = std::move(s_bind_defaults);
            else
              s_bind_mounts = s_bind_defaults + ',' + s_bind_mounts;
          }

        // unconditionally set these two variables so they don't become an
        // accidental user interface
        s.setenv("SLURM_SINGULARITY_BIND", s_bind_mounts.c_str());
        s.setenv("SLURM_SINGULARITY_ARGS", s_singularity_args.c_str());
        std::vector<char*> argv = s.job_argument_vector();
        argv.insert(argv.begin(),
                    { s_singularity_script.data(), s_container_name.data() });
        argv.push_back(nullptr);
        if (-1
            == execvpe(s_singularity_script.c_str(), argv.data(), s.job_env()))
          {
            const auto error = std::strerror(errno);
            slurm_error("Starting %s in %s failed: %s", argv[0],
                        s_container_name.c_str(), error);
            return -ESPANK_ERROR;
          }
        __builtin_unreachable();
      }
    catch (const Buttocks::SpankError& err)
      {
        slurm_error("singularity-exec error: %s", err.what());
        return -err.code();
      }
  }
};

extern "C"
{ // SPANK plugin interface
  int
  slurm_spank_init(spank_t sp, const int count, char* argv[])
  {
    return singularity_exec::init(sp, { count, argv });
  }

  int
  slurm_spank_task_init(spank_t sp, const int argc, char* argv[])
  {
    return singularity_exec::start_container(sp, { argc, argv });
  }

  extern const char plugin_name[] = "singularity-exec";
  extern const char plugin_type[] = "spank";
  extern const unsigned int plugin_version = 0;
}

// vim: foldmethod=marker foldmarker={,} sw=2 et
