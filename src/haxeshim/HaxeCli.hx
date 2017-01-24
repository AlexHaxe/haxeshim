package haxeshim;

using StringTools;
using tink.CoreApi;

class HaxeCli {
    
  static function die(code, reason):Dynamic {
    Sys.stderr().writeString('$reason\n');
    Sys.exit(code);    
    return throw 'unreachable';
  }
  static function gracefully<T>(f:Void->T) 
    return 
      try f()
      catch (e:Error) 
        die(e.code, e.message)
      catch (e:Dynamic) 
        die(500, Std.string(e));
  
  var scope:Scope;
        
  public function new(scope) {
    this.scope = scope;
  }
  
  static function main() {
    new HaxeCli(gracefully(Scope.seek.bind())).dispatch(Sys.args()); 
  }
  
  public function installLibs(silent:Bool) {
    var i = scope.getInstallationInstructions();
        
    var code = 0;
    
    switch i.missing {
      case []:
      case v:
        code = 404;
        for (m in v)
          Sys.stderr().writeString('${m.lib} has no install instruction for missing classpath ${m.cp}\n');
    }
    
    for (cmd in i.instructions) {
      if (!silent)
        Sys.println(cmd);
      switch Exec.shell(cmd, Sys.getCwd()) {
        case Failure(e):
          code = e.code;
        default:
      }
    }
    
    Sys.exit(code);    
  }
  
  function dispatch(args:Array<String>) 
    switch args {
      case ['--wait', 'stdio']:
        
        new CompilerServer(Stdio, Scope.seek());
        
      case ['--wait', Std.parseInt(_) => port]:
        
        new CompilerServer(Port(port), Scope.seek());
      
      case _.slice(0, 2) => ['--run', haxeShimExtension] if (haxeShimExtension.indexOf('-') != -1 && haxeShimExtension.toLowerCase() == haxeShimExtension):
        
        var args = args.slice(2);
        var scope = gracefully(Scope.seek.bind());
        
        switch haxeShimExtension {
          case 'install-libs':
            
            installLibs(switch args {
              case ['--silent']: true;
              case []: false;
              default: die(422, 'unexpected arguments $args');
            });
            
          case 'resolve-args':
            
            Sys.println(gracefully(scope.resolve.bind(args)).join('\n'));
            Sys.exit(0);
            
          case 'show-version':
            
            if (args.length > 0)
              die(422, 'too many arguments');
            
            var version = 
              switch Exec.eval(scope.haxeInstallation.compiler, scope.cwd, ['-version']) {
                case Success(v):
                  (v.stdout.toString() + v.stderr.toString()).trim();
                case Failure(e):
                  die(e.code, e.message);
              }
            
            Sys.println('-D haxe-ver=$version');
            Sys.println('-cp ${scope.haxeInstallation.stdLib}');
            
          case v:
            die(404, 'Unknown extension $v');
        }
        
      case args:
        
        var scope = gracefully(Scope.seek.bind());
        
        switch [args.indexOf('--connect'), args.indexOf('--haxe-version')] {
          case [ -1, -1]:
          case [ _, -1]: 
            /**
             * TODO: in this case there are two possible optimizations:
             * 
             * 1. Connect to the server directly (protocol seems easy enough)
             * 2. Leave the version determination to the server side, because it is already running
             */
            args.push('--haxe-version');
            args.push(scope.haxeInstallation.version);
          default:
        }
        Sys.exit(gracefully(Exec.sync(scope.haxeInstallation.compiler, scope.cwd, gracefully(scope.resolve.bind(args)), scope.haxeInstallation.env()).sure));
    }
  
  
}

