document.addEventListener('DOMContentLoaded', function blockAnchors() {
  const stopPropagation = (event) => event.stopPropagation()
  const blockAnchorJSNavigation = (anchor) =>
    [
      'click',
      'keydown',
      'auxclick',
      'contextmenu',
      'touchend',
      'dragend',
    ].forEach((ev) => anchor.addEventListener(ev, stopPropagation))

  const blockAll = (target = document) => {
    target.querySelectorAll('a').forEach(function (anchor) {
      blockAnchorJSNavigation(anchor)
      anchor.addEventListener = () => {}
    })
  }

  blockAll()

  new MutationObserver((records) =>
    records.forEach((record) => blockAll(record.target)),
  ).observe(document.body, {
    childList: true,
    subtree: true,
  })
})
