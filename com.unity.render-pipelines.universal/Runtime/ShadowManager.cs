using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace UnityEngine.Rendering.Universal
{
    public class ShadowManager
    {
        private static ShadowManager instance = new ShadowManager();
        static List<Renderer> m_listRenderer;

        ShadowManager()
        {
            m_listRenderer = new List<Renderer>();
        }

        static public ShadowManager Instance
        {
            get { return instance; }
        }

        public void AddRenderer(Renderer renderer)
        {
            m_listRenderer.Add(renderer);
        }


        public void AddRenderer(Renderer[] renderer)
        {
            m_listRenderer.AddRange(renderer);
        }


        public void RemoveRenderer(Renderer renderer)
        {
            m_listRenderer.Remove(renderer);
        }


        public void RemoveRenderer(Renderer[] renderer)
        {
            foreach (var r in renderer)
            {
                RemoveRenderer(r);
            }
        }

        public bool GetCasterBounds(out Bounds bounds)
        {
            if (m_listRenderer.Count == 0)
            {
                //bounds.SetMinMax(Vector3.zero, Vector3.zero);
                bounds = new Bounds();
                return false;
            }

            bounds = m_listRenderer[0].bounds;
            for (int i = 1; i != m_listRenderer.Count; ++i)
            {
                bounds.Encapsulate(m_listRenderer[i].bounds);
            }
            return true;
        }
    }
}
