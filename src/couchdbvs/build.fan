class Build : build::BuildPod
{
	new make()
	{
		podName = "couchdbvs"
		summary = "CouchDB view server pod"
		depends = ["sys 1.0", "util 1.0", "compiler 1.0", "web 1.0"]
		srcDirs = [`fan/`]
	}
}

