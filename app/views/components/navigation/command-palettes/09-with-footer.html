<!-- Include this script tag or install `@tailwindplus/elements` via npm: -->
<!-- <script src="https://cdn.jsdelivr.net/npm/@tailwindplus/elements@1" type="module"></script> -->
<script type="module">
  function onReady() {
    let command = document.getElementById('command')

    command.querySelector('input').addEventListener('input', (event) => {
      let value = event.target.value
      if (value === '?') {
        command.dataset.mode = 'help'
      } else if (value.startsWith('#')) {
        command.dataset.mode = 'project'
      } else if (value.startsWith('>')) {
        command.dataset.mode = 'user'
      } else {
        delete command.dataset.mode
      }
    })

    command.setFilterCallback(({ query, node, content }) => {
      if (query === '?') {
        return false
      }
      if (query.startsWith('#')) {
        return node.dataset.type === 'project' && content.toLowerCase().includes(query.slice(1).toLowerCase())
      }
      if (query.startsWith('>')) {
        return node.dataset.type === 'user' && content.toLowerCase().includes(query.slice(1).toLowerCase())
      }
      return content.toLowerCase().includes(query.toLowerCase())
    })
  }

  if (customElements.get('el-command')) {
    onReady()
  } else {
    window.addEventListener('elements:ready', onReady)
  }
</script>

<button command="show-modal" commandfor="dialog" class="rounded-md bg-white/80 px-2.5 py-1.5 text-sm font-semibold text-gray-900 hover:bg-white/90 dark:bg-gray-800/80 dark:text-white dark:hover:bg-gray-800/90">Open command palette</button>

<el-dialog>
  <dialog id="dialog" class="backdrop:bg-transparent">
    <el-dialog-backdrop class="fixed inset-0 bg-gray-500/25 transition-opacity data-closed:opacity-0 data-enter:duration-300 data-enter:ease-out data-leave:duration-200 data-leave:ease-in dark:bg-gray-900/50"></el-dialog-backdrop>

    <div tabindex="0" class="fixed inset-0 w-screen overflow-y-auto p-4 focus:outline-none sm:p-6 md:p-20">
      <el-dialog-panel class="mx-auto block max-w-xl transform overflow-hidden rounded-xl bg-white shadow-2xl outline-1 outline-black/5 transition-all data-closed:scale-95 data-closed:opacity-0 data-enter:duration-300 data-enter:ease-out data-leave:duration-200 data-leave:ease-in dark:bg-gray-900 dark:-outline-offset-1 dark:outline-white/10">
        <el-command-palette id="command" class="divide-y divide-gray-100 dark:divide-white/10">
          <div class="grid grid-cols-1">
            <input type="text" autofocus placeholder="Search..." class="col-start-1 row-start-1 h-12 w-full pr-4 pl-11 text-base text-gray-900 outline-hidden placeholder:text-gray-400 sm:text-sm dark:bg-gray-900 dark:text-white dark:placeholder:text-gray-500" />
            <svg viewBox="0 0 20 20" fill="currentColor" data-slot="icon" aria-hidden="true" class="pointer-events-none col-start-1 row-start-1 ml-4 size-5 self-center text-gray-400 dark:text-gray-500">
              <path d="M9 3.5a5.5 5.5 0 1 0 0 11 5.5 5.5 0 0 0 0-11ZM2 9a7 7 0 1 1 12.452 4.391l3.328 3.329a.75.75 0 1 1-1.06 1.06l-3.329-3.328A7 7 0 0 1 2 9Z" clip-rule="evenodd" fill-rule="evenodd" />
            </svg>
          </div>

          <el-command-list hidden class="flex max-h-80 transform-gpu scroll-py-10 scroll-pb-2 flex-col gap-4 overflow-y-auto p-4 pb-2">
            <el-command-group hidden aria-labelledby="projects-label">
              <h2 id="projects-label" class="text-xs font-semibold text-gray-900 dark:text-white">Projects</h2>
              <div class="-mx-4 mt-2 text-sm text-gray-700 dark:text-gray-300">
                <a href="#" hidden data-type="project" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" data-slot="icon" aria-hidden="true" class="size-6 flex-none text-gray-400 group-aria-selected:text-white dark:text-gray-500 forced-colors:group-aria-selected:text-[Highlight]">
                    <path d="M2.25 12.75V12A2.25 2.25 0 0 1 4.5 9.75h15A2.25 2.25 0 0 1 21.75 12v.75m-8.69-6.44-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z" stroke-linecap="round" stroke-linejoin="round" />
                  </svg>
                  <span class="ml-3 flex-auto truncate">Workflow Inc. / Website Redesign</span>
                </a>
                <a href="#" hidden data-type="project" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" data-slot="icon" aria-hidden="true" class="size-6 flex-none text-gray-400 group-aria-selected:text-white dark:text-gray-500 forced-colors:group-aria-selected:text-[Highlight]">
                    <path d="M2.25 12.75V12A2.25 2.25 0 0 1 4.5 9.75h15A2.25 2.25 0 0 1 21.75 12v.75m-8.69-6.44-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z" stroke-linecap="round" stroke-linejoin="round" />
                  </svg>
                  <span class="ml-3 flex-auto truncate">Workflow Inc. / Open Graph Image</span>
                </a>
                <a href="#" hidden data-type="project" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" data-slot="icon" aria-hidden="true" class="size-6 flex-none text-gray-400 group-aria-selected:text-white dark:text-gray-500 forced-colors:group-aria-selected:text-[Highlight]">
                    <path d="M2.25 12.75V12A2.25 2.25 0 0 1 4.5 9.75h15A2.25 2.25 0 0 1 21.75 12v.75m-8.69-6.44-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z" stroke-linecap="round" stroke-linejoin="round" />
                  </svg>
                  <span class="ml-3 flex-auto truncate">Workflow Inc. / Logo Design</span>
                </a>
                <a href="#" hidden data-type="project" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" data-slot="icon" aria-hidden="true" class="size-6 flex-none text-gray-400 group-aria-selected:text-white dark:text-gray-500 forced-colors:group-aria-selected:text-[Highlight]">
                    <path d="M2.25 12.75V12A2.25 2.25 0 0 1 4.5 9.75h15A2.25 2.25 0 0 1 21.75 12v.75m-8.69-6.44-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z" stroke-linecap="round" stroke-linejoin="round" />
                  </svg>
                  <span class="ml-3 flex-auto truncate">Workflow Inc. / Advertising Campaign</span>
                </a>
                <a href="#" hidden data-type="project" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" data-slot="icon" aria-hidden="true" class="size-6 flex-none text-gray-400 group-aria-selected:text-white dark:text-gray-500 forced-colors:group-aria-selected:text-[Highlight]">
                    <path d="M2.25 12.75V12A2.25 2.25 0 0 1 4.5 9.75h15A2.25 2.25 0 0 1 21.75 12v.75m-8.69-6.44-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z" stroke-linecap="round" stroke-linejoin="round" />
                  </svg>
                  <span class="ml-3 flex-auto truncate">Conglomerate Inc. / TV Ad Campaign</span>
                </a>
                <a href="#" hidden data-type="project" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" data-slot="icon" aria-hidden="true" class="size-6 flex-none text-gray-400 group-aria-selected:text-white dark:text-gray-500 forced-colors:group-aria-selected:text-[Highlight]">
                    <path d="M2.25 12.75V12A2.25 2.25 0 0 1 4.5 9.75h15A2.25 2.25 0 0 1 21.75 12v.75m-8.69-6.44-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z" stroke-linecap="round" stroke-linejoin="round" />
                  </svg>
                  <span class="ml-3 flex-auto truncate">Conglomerate Inc. / Mobile App</span>
                </a>
                <a href="#" hidden data-type="project" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" data-slot="icon" aria-hidden="true" class="size-6 flex-none text-gray-400 group-aria-selected:text-white dark:text-gray-500 forced-colors:group-aria-selected:text-[Highlight]">
                    <path d="M2.25 12.75V12A2.25 2.25 0 0 1 4.5 9.75h15A2.25 2.25 0 0 1 21.75 12v.75m-8.69-6.44-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z" stroke-linecap="round" stroke-linejoin="round" />
                  </svg>
                  <span class="ml-3 flex-auto truncate">Conglomerate Inc. / Product Design</span>
                </a>
                <a href="#" hidden data-type="project" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" data-slot="icon" aria-hidden="true" class="size-6 flex-none text-gray-400 group-aria-selected:text-white dark:text-gray-500 forced-colors:group-aria-selected:text-[Highlight]">
                    <path d="M2.25 12.75V12A2.25 2.25 0 0 1 4.5 9.75h15A2.25 2.25 0 0 1 21.75 12v.75m-8.69-6.44-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z" stroke-linecap="round" stroke-linejoin="round" />
                  </svg>
                  <span class="ml-3 flex-auto truncate">Conglomerate Inc. / Intranet</span>
                </a>
                <a href="#" hidden data-type="project" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" data-slot="icon" aria-hidden="true" class="size-6 flex-none text-gray-400 group-aria-selected:text-white dark:text-gray-500 forced-colors:group-aria-selected:text-[Highlight]">
                    <path d="M2.25 12.75V12A2.25 2.25 0 0 1 4.5 9.75h15A2.25 2.25 0 0 1 21.75 12v.75m-8.69-6.44-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z" stroke-linecap="round" stroke-linejoin="round" />
                  </svg>
                  <span class="ml-3 flex-auto truncate">Conglomerate Inc. / Custom Programming</span>
                </a>
                <a href="#" hidden data-type="project" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" data-slot="icon" aria-hidden="true" class="size-6 flex-none text-gray-400 group-aria-selected:text-white dark:text-gray-500 forced-colors:group-aria-selected:text-[Highlight]">
                    <path d="M2.25 12.75V12A2.25 2.25 0 0 1 4.5 9.75h15A2.25 2.25 0 0 1 21.75 12v.75m-8.69-6.44-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z" stroke-linecap="round" stroke-linejoin="round" />
                  </svg>
                  <span class="ml-3 flex-auto truncate">Multinational LLC. / Creative Writing</span>
                </a>
                <a href="#" hidden data-type="project" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" data-slot="icon" aria-hidden="true" class="size-6 flex-none text-gray-400 group-aria-selected:text-white dark:text-gray-500 forced-colors:group-aria-selected:text-[Highlight]">
                    <path d="M2.25 12.75V12A2.25 2.25 0 0 1 4.5 9.75h15A2.25 2.25 0 0 1 21.75 12v.75m-8.69-6.44-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z" stroke-linecap="round" stroke-linejoin="round" />
                  </svg>
                  <span class="ml-3 flex-auto truncate">Multinational LLC. / Animation</span>
                </a>
                <a href="#" hidden data-type="project" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" data-slot="icon" aria-hidden="true" class="size-6 flex-none text-gray-400 group-aria-selected:text-white dark:text-gray-500 forced-colors:group-aria-selected:text-[Highlight]">
                    <path d="M2.25 12.75V12A2.25 2.25 0 0 1 4.5 9.75h15A2.25 2.25 0 0 1 21.75 12v.75m-8.69-6.44-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z" stroke-linecap="round" stroke-linejoin="round" />
                  </svg>
                  <span class="ml-3 flex-auto truncate">Multinational LLC. / Product Illustration</span>
                </a>
                <a href="#" hidden data-type="project" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" data-slot="icon" aria-hidden="true" class="size-6 flex-none text-gray-400 group-aria-selected:text-white dark:text-gray-500 forced-colors:group-aria-selected:text-[Highlight]">
                    <path d="M2.25 12.75V12A2.25 2.25 0 0 1 4.5 9.75h15A2.25 2.25 0 0 1 21.75 12v.75m-8.69-6.44-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z" stroke-linecap="round" stroke-linejoin="round" />
                  </svg>
                  <span class="ml-3 flex-auto truncate">Products Inc. / Video Production</span>
                </a>
                <a href="#" hidden data-type="project" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" data-slot="icon" aria-hidden="true" class="size-6 flex-none text-gray-400 group-aria-selected:text-white dark:text-gray-500 forced-colors:group-aria-selected:text-[Highlight]">
                    <path d="M2.25 12.75V12A2.25 2.25 0 0 1 4.5 9.75h15A2.25 2.25 0 0 1 21.75 12v.75m-8.69-6.44-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z" stroke-linecap="round" stroke-linejoin="round" />
                  </svg>
                  <span class="ml-3 flex-auto truncate">Products Inc. / Print Brochure</span>
                </a>
                <a href="#" hidden data-type="project" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" data-slot="icon" aria-hidden="true" class="size-6 flex-none text-gray-400 group-aria-selected:text-white dark:text-gray-500 forced-colors:group-aria-selected:text-[Highlight]">
                    <path d="M2.25 12.75V12A2.25 2.25 0 0 1 4.5 9.75h15A2.25 2.25 0 0 1 21.75 12v.75m-8.69-6.44-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z" stroke-linecap="round" stroke-linejoin="round" />
                  </svg>
                  <span class="ml-3 flex-auto truncate">Products Inc. / Documentation</span>
                </a>
              </div>
            </el-command-group>

            <el-command-group hidden aria-labelledby="users-label">
              <h2 id="users-label" class="text-xs font-semibold text-gray-900 dark:text-white">Users</h2>
              <div class="-mx-4 mt-2 text-sm text-gray-700 dark:text-gray-300">
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1494790108377-be9c29b29330?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Leslie Alexander</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1519244703995-f4e0f30006d5?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Michael Foster</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Dries Vincent</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1517841905240-472988babdf9?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Lindsay Walton</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1438761681033-6461ffad8d80?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Courtney Henry</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Tom Cook</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1517365830460-955ce3ccd263?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Whitney Francis</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1519345182560-3f2917c472ef?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Leonard Krasner</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1463453091185-61582044d556?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Floyd Miles</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1502685104226-ee32379fefbe?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Emily Selman</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1500917293891-ef795e70e1f6?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Kristin Watson</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1505840717430-882ce147ef2d?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Emma Dorsey</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1509783236416-c9ad59bae472?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Alicia Bell</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1507101105822-7472b28e22ac?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Jenny Wilson</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1534528741775-53994a69daeb?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Anna Roberts</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1531427186611-ecfd6d936c79?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Benjamin Russel</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1517070208541-6ddc4d3efbcb?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Jeffrey Webb</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Kathryn Murphy</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1513910367299-bce8d8a0ebf6?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Lawrence Hunter</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1506980595904-70325b7fdd90?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Yvette Armstrong</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1501031170107-cfd33f0cbdcc?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Angela Fisher</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1520785643438-5bf77931f493?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Blake Reid</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1500648767791-00dcc994a43e?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Hector Gibbons</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Fabricio Mendes</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1504703395950-b89145a5425b?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Jillian Steward</span>
                </a>
                <a href="#" hidden data-type="user" class="group flex cursor-default items-center px-4 py-2 select-none focus:outline-hidden aria-selected:bg-indigo-600 aria-selected:text-white dark:aria-selected:bg-indigo-500">
                  <img src="https://images.unsplash.com/photo-1550525811-e5869dd03032?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="" class="size-6 flex-none rounded-full bg-gray-100 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10" />
                  <span class="ml-3 flex-auto truncate">Chelsea Hagon</span>
                </a>
              </div>
            </el-command-group>
          </el-command-list>

          <div class="hidden px-6 py-14 text-center text-sm in-data-[mode=help]:block sm:px-14">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" data-slot="icon" aria-hidden="true" class="mx-auto size-6 text-gray-400 dark:text-gray-500">
              <path d="M16.712 4.33a9.027 9.027 0 0 1 1.652 1.306c.51.51.944 1.064 1.306 1.652M16.712 4.33l-3.448 4.138m3.448-4.138a9.014 9.014 0 0 0-9.424 0M19.67 7.288l-4.138 3.448m4.138-3.448a9.014 9.014 0 0 1 0 9.424m-4.138-5.976a3.736 3.736 0 0 0-.88-1.388 3.737 3.737 0 0 0-1.388-.88m2.268 2.268a3.765 3.765 0 0 1 0 2.528m-2.268-4.796a3.765 3.765 0 0 0-2.528 0m4.796 4.796c-.181.506-.475.982-.88 1.388a3.736 3.736 0 0 1-1.388.88m2.268-2.268 4.138 3.448m0 0a9.027 9.027 0 0 1-1.306 1.652c-.51.51-1.064.944-1.652 1.306m0 0-3.448-4.138m3.448 4.138a9.014 9.014 0 0 1-9.424 0m5.976-4.138a3.765 3.765 0 0 1-2.528 0m0 0a3.736 3.736 0 0 1-1.388-.88 3.737 3.737 0 0 1-.88-1.388m2.268 2.268L7.288 19.67m0 0a9.024 9.024 0 0 1-1.652-1.306 9.027 9.027 0 0 1-1.306-1.652m0 0 4.138-3.448M4.33 16.712a9.014 9.014 0 0 1 0-9.424m4.138 5.976a3.765 3.765 0 0 1 0-2.528m0 0c.181-.506.475-.982.88-1.388a3.736 3.736 0 0 1 1.388-.88m-2.268 2.268L4.33 7.288m6.406 1.18L7.288 4.33m0 0a9.024 9.024 0 0 0-1.652 1.306A9.025 9.025 0 0 0 4.33 7.288" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
            <p class="mt-4 font-semibold text-gray-900 dark:text-white">Help with searching</p>
            <p class="mt-2 text-gray-500 dark:text-gray-400">Use this tool to quickly search for users and projects across our entire platform. You can also use the search modifiers found in the footer below to limit the results to just users or projects.</p>
          </div>

          <el-no-results hidden class="block px-6 py-14 text-center text-sm in-data-[mode=help]:hidden sm:px-14">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" data-slot="icon" aria-hidden="true" class="mx-auto size-6 text-gray-400 dark:text-gray-500">
              <path d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
            <p class="mt-4 font-semibold text-gray-900 dark:text-white">No results found</p>
            <p class="mt-2 text-gray-500 dark:text-gray-400">We couldn’t find anything with that term. Please try again.</p>
          </el-no-results>

          <div class="flex flex-wrap items-center bg-gray-50 px-4 py-2.5 text-xs text-gray-700 dark:bg-gray-800/50 dark:text-gray-300">Type <kbd class="mx-1 flex size-5 items-center justify-center rounded-sm border border-gray-400 bg-white font-semibold text-gray-900 in-data-[mode=project]:border-indigo-600 in-data-[mode=project]:text-indigo-600 sm:mx-2 dark:border-white/10 dark:bg-gray-800 dark:text-white dark:in-data-[mode=project]:border-indigo-500 dark:in-data-[mode=project]:text-indigo-500">#</kbd> <span class="sm:hidden">for projects,</span><span class="hidden sm:inline">to access projects,</span><kbd class="mx-1 flex size-5 items-center justify-center rounded-sm border border-gray-400 bg-white font-semibold text-gray-900 in-data-[mode=user]:border-indigo-600 in-data-[mode=user]:text-indigo-600 sm:mx-2 dark:border-white/10 dark:bg-gray-800 dark:text-white dark:in-data-[mode=user]:border-indigo-500 dark:in-data-[mode=user]:text-indigo-500">&gt;</kbd> for users, and <kbd class="mx-1 flex size-5 items-center justify-center rounded-sm border border-gray-400 bg-white font-semibold text-gray-900 in-data-[mode=help]:border-indigo-600 in-data-[mode=help]:text-indigo-600 sm:mx-2 dark:border-white/10 dark:bg-gray-800 dark:text-white dark:in-data-[mode=help]:border-indigo-500 dark:in-data-[mode=help]:text-indigo-500">?</kbd> for help.</div>
        </el-command-palette>
      </el-dialog-panel>
    </div>
  </dialog>
</el-dialog>
