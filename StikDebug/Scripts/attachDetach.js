function attach() {
    log("Welcome to use StikDebug's scripting feature! Here you can use JavaScript to customize your debug experience!")
    log("This script is a demo script that attaches to the connected app and detaches from it.")
    
    // get pid of the connected app
    let pid = get_pid();
    log(`pid = ${pid}`)
    
    // attach
    let attachResponse = send_command(`vAttach;${pid.toString(16)}`)
    log(`attach_response = ${attachResponse}`)
    
    // detach
    let detachResponse = send_command(`D`)
    log(`detachResponse = ${detachResponse}`)
}

attach()
